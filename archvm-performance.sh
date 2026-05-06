#!/usr/bin/env bash
# ============================================================
#  ArchVM Performance Tuning Script
#  Phase 3: Deep system optimization
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
ok()     { echo -e "${GREEN}[OK]${RESET} $*"; }
banner() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }

banner "System Performance Optimizer"

# ─── Kernel Parameters ──────────────────────────────────────
sudo tee /etc/sysctl.d/99-archvm.conf > /dev/null <<'EOF'
# ── Memory Management ─────────────────────────
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=3
vm.dirty_expire_centisecs=3000
vm.dirty_writeback_centisecs=1500
vm.vfs_cache_pressure=50
vm.page-cluster=0
vm.overcommit_memory=1

# ── Huge Pages ────────────────────────────────
vm.nr_hugepages=128

# ── Network ───────────────────────────────────
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.netdev_max_backlog=16384
net.core.somaxconn=8192
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_tw_reuse=1
net.ipv4.ip_local_port_range=1024 65535

# ── Kernel ────────────────────────────────────
kernel.sched_autogroup_enabled=1
kernel.sched_migration_cost_ns=5000000
kernel.nmi_watchdog=0
kernel.unprivileged_userns_clone=1
EOF
sudo sysctl -p /etc/sysctl.d/99-archvm.conf &>/dev/null
ok "Kernel parameters applied"

# ─── CPU Governor ───────────────────────────────────────────
sudo pacman -S --noconfirm cpupower 2>/dev/null || true
sudo cpupower frequency-set -g performance 2>/dev/null || true
sudo tee /etc/systemd/system/cpupower.service > /dev/null <<'EOF'
[Unit]
Description=CPU Power Governor
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/cpupower frequency-set -g performance
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable cpupower.service 2>/dev/null || true
ok "CPU governor: performance"

# ─── Ananicy-CPP (process priority) ─────────────────────────
yay -S --noconfirm ananicy-cpp ananicy-rules-git 2>/dev/null || true
sudo systemctl enable ananicy-cpp 2>/dev/null || true
ok "ananicy-cpp: auto process priority"

# ─── Preload (faster app launch) ────────────────────────────
yay -S --noconfirm preload 2>/dev/null || true
sudo systemctl enable preload 2>/dev/null || true
ok "preload: app prefetch enabled"

# ─── earlyoom (prevent system freeze) ───────────────────────
sudo pacman -S --noconfirm earlyoom 2>/dev/null || true
sudo systemctl enable earlyoom
sudo tee /etc/earlyoom.conf > /dev/null <<'EOF'
EARLYOOM_ARGS="-r 60 -m 5 -s 5 --avoid '(^|/)(Xorg|i3|alacritty|sddm)$' --prefer '(^|/)(electron|chrome|firefox)$'"
EOF
ok "earlyoom: OOM protection enabled"

# ─── systemd-oomd ────────────────────────────────────────────
sudo systemctl enable systemd-oomd 2>/dev/null || true

# ─── Trim & Disk ────────────────────────────────────────────
sudo systemctl enable fstrim.timer 2>/dev/null || true
# Readahead
sudo tee /etc/udev/rules.d/60-readahead.rules > /dev/null <<'EOF'
ACTION=="add", KERNEL=="sd[a-z]", ATTR{queue/read_ahead_kb}="512"
ACTION=="add", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/read_ahead_kb}="512"
EOF
ok "Disk: TRIM and readahead configured"

# ─── Journald (limit log size) ───────────────────────────────
sudo mkdir -p /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/archvm.conf > /dev/null <<'EOF'
[Journal]
SystemMaxUse=100M
SystemKeepFree=500M
MaxRetentionSec=1week
ForwardToSyslog=no
EOF
sudo systemctl restart systemd-journald
ok "journald: log limits set"

# ─── Pacman & makepkg Optimization ──────────────────────────
CORES=$(nproc)
sudo sed -i "s/^#MAKEFLAGS=.*/MAKEFLAGS=\"-j${CORES}\"/" /etc/makepkg.conf
sudo sed -i 's/^COMPRESSXZ=.*/COMPRESSXZ=(xz -c -z - --threads=0)/' /etc/makepkg.conf
sudo sed -i 's/^PKGEXT=.*/PKGEXT='"'"'.pkg.tar.zst'"'"'/' /etc/makepkg.conf
# Enable parallel downloads
sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
sudo sed -i 's/^ParallelDownloads = .*/ParallelDownloads = 10/' /etc/pacman.conf
# Enable color
sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
ok "pacman: parallel downloads, color, optimized"

# ─── Font rendering ──────────────────────────────────────────
sudo tee /etc/fonts/local.conf > /dev/null <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hinting" mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle" mode="assign"><const>hintfull</const></edit>
    <edit name="rgba" mode="assign"><const>rgb</const></edit>
    <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
  </match>
</fontconfig>
EOF
fc-cache -fv &>/dev/null
ok "Font rendering: antialiased & hinted"

# ─── Pacman cache cleanup timer ─────────────────────────────
sudo tee /etc/systemd/system/paccache.service > /dev/null <<'EOF'
[Unit]
Description=Clean pacman package cache

[Service]
Type=oneshot
ExecStart=/usr/bin/paccache -r
EOF
sudo tee /etc/systemd/system/paccache.timer > /dev/null <<'EOF'
[Unit]
Description=Weekly pacman cache cleanup

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF
sudo systemctl enable paccache.timer 2>/dev/null || true
ok "paccache: weekly cleanup scheduled"

# ─── Power management ────────────────────────────────────────
sudo pacman -S --noconfirm tlp 2>/dev/null || true
sudo systemctl enable tlp 2>/dev/null || true
ok "TLP: power management enabled"

banner "All Performance Tweaks Applied!"
echo "  CPU governor  : performance"
echo "  Swappiness    : 10  (prefer RAM)"
echo "  TCP           : BBR congestion + fast open"
echo "  zram          : active (RAM swap)"
echo "  ananicy-cpp   : process priorities"
echo "  preload       : app prefetch"
echo "  earlyoom      : freeze prevention"
echo "  journald      : 100MB max"
echo "  fstrim        : weekly SSD trim"
echo ""
