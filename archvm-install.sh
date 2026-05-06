#!/usr/bin/env bash
# ============================================================
#  ArchVM Install Script
#  Dark · Performance · VMware Ready
#  Phase 1: Base System Installation
# ============================================================
set -euo pipefail

# ─── Colors ─────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
err()     { echo -e "${RED}[ERR]${RESET}   $*"; exit 1; }
banner()  { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════${RESET}"; echo -e "${BOLD}${CYAN}  $*${RESET}"; echo -e "${BOLD}${CYAN}══════════════════════════════════════${RESET}\n"; }

banner "ArchVM — Dark Performance Edition"
echo -e "  Designed for VMware · Catppuccin Mocha Dark"
echo ""

# ─── Config ─────────────────────────────────────────────────
DISK="/dev/sda"
HOSTNAME="archvm"
USERNAME="void"
TIMEZONE="Asia/Kolkata"
LOCALE="en_IN.UTF-8"
KEYMAP="us"
ROOT_PASS="archvm2024"
USER_PASS="archvm2024"

# ─── Preflight Checks ────────────────────────────────────────
banner "Preflight Checks"
[[ -d /sys/firmware/efi ]] && BOOT_MODE="uefi" || BOOT_MODE="bios"
info "Boot mode: $BOOT_MODE"
ping -c1 archlinux.org &>/dev/null || err "No internet connection"
ok "Internet: OK"
timedatectl set-ntp true && ok "NTP synced"

# ─── Partition ───────────────────────────────────────────────
banner "Partitioning $DISK"
warn "This will WIPE $DISK — press Ctrl+C within 5s to abort"
sleep 5

if [[ "$BOOT_MODE" == "uefi" ]]; then
  parted -s "$DISK" \
    mklabel gpt \
    mkpart ESP fat32 1MiB 512MiB \
    set 1 esp on \
    mkpart primary linux-swap 512MiB 4GiB \
    mkpart primary ext4 4GiB 100%
  BOOT_PART="${DISK}1"
  SWAP_PART="${DISK}2"
  ROOT_PART="${DISK}3"
  mkfs.fat -F32 "$BOOT_PART"
else
  parted -s "$DISK" \
    mklabel msdos \
    mkpart primary linux-swap 1MiB 4GiB \
    mkpart primary ext4 4GiB 100%
  SWAP_PART="${DISK}1"
  ROOT_PART="${DISK}2"
fi

mkswap "$SWAP_PART" && swapon "$SWAP_PART" && ok "Swap: ready"
mkfs.ext4 -F -L archvm "$ROOT_PART"  && ok "Root: formatted ext4"
mount "$ROOT_PART" /mnt
[[ "$BOOT_MODE" == "uefi" ]] && { mkdir -p /mnt/boot/efi; mount "$BOOT_PART" /mnt/boot/efi; }

# ─── Mirror Optimization ────────────────────────────────────
banner "Optimizing Mirrors"
pacman -Sy --noconfirm reflector 2>/dev/null || true
reflector --country India --protocol https --sort rate --latest 10 \
  --save /etc/pacman.d/mirrorlist 2>/dev/null || warn "Reflector failed; using defaults"
ok "Mirrors set"

# ─── Base Install ────────────────────────────────────────────
banner "Installing Base System"
pacstrap -K /mnt \
  base base-devel linux linux-lts linux-firmware \
  intel-ucode amd-ucode \
  networkmanager network-manager-applet \
  grub efibootmgr os-prober \
  vim nano git curl wget \
  sudo bash-completion \
  open-vm-tools xf86-video-vmware xf86-input-vmmouse \
  gtkmm3 \
  zsh zsh-completions zsh-syntax-highlighting zsh-autosuggestions \
  pipewire pipewire-alsa pipewire-pulse wireplumber \
  htop btop neofetch tree ripgrep fd bat eza fzf \
  python python-pip nodejs npm \
  man-db man-pages

ok "Base packages installed"
genfstab -U /mnt >> /mnt/etc/fstab && ok "fstab generated"

# ─── Chroot Setup ────────────────────────────────────────────
banner "Configuring System (chroot)"
arch-chroot /mnt /bin/bash <<CHROOT
set -e

# ── Locale & Time ──────────────────────────────
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
sed -i 's/^#en_IN.UTF-8/en_IN.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# ── Hostname ───────────────────────────────────
echo "$HOSTNAME" > /etc/hostname
cat >> /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF

# ── Users ──────────────────────────────────────
echo "root:$ROOT_PASS" | chpasswd
useradd -m -G wheel,audio,video,storage,optical,network -s /bin/zsh $USERNAME
echo "$USERNAME:$USER_PASS" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# ── Performance Kernel Params ──────────────────
cat > /etc/sysctl.d/99-performance.conf <<EOF
# Memory
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.vfs_cache_pressure=50
vm.page-cluster=0

# Network
net.core.netdev_max_backlog=16384
net.core.somaxconn=8192
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=16777216
net.core.wmem_max=16777216

# Security hardening
kernel.dmesg_restrict=1
kernel.kptr_restrict=2
net.ipv4.conf.default.rp_filter=1
EOF

# ── CPU Governor ───────────────────────────────
cat > /etc/tmpfiles.d/cpu-governor.conf <<EOF
w /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor - - - - performance
EOF

# ── IRQ Balance ────────────────────────────────
pacman -S --noconfirm irqbalance 2>/dev/null || true
systemctl enable irqbalance 2>/dev/null || true

# ── zram (compressed swap in RAM) ─────────────
pacman -S --noconfirm zram-generator
cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF

# ── I/O Scheduler ─────────────────────────────
cat > /etc/udev/rules.d/60-scheduler.rules <<EOF
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="mq-deadline"
EOF

# ── Trim (SSD) ────────────────────────────────
systemctl enable fstrim.timer

# ── Bootloader ────────────────────────────────
if [[ -d /sys/firmware/efi ]]; then
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ArchVM
else
  grub-install --target=i386-pc $DISK
fi

# Add performance params to GRUB
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 nowatchdog page_alloc.shuffle=1 transparent_hugepage=madvise mitigations=off"/' /etc/default/grub
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=2/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# ── VMware Services ───────────────────────────
systemctl enable vmtoolsd
systemctl enable vmware-vmblock-fuse
systemctl enable NetworkManager

CHROOT

ok "Base system configured"

# ─── Copy Post-Install Script ────────────────────────────────
cp /root/archvm-post-install.sh /mnt/home/$USERNAME/ 2>/dev/null || true
cp /root/archvm-performance.sh /mnt/home/$USERNAME/ 2>/dev/null || true

banner "Phase 1 Complete!"
echo -e "${GREEN}✔ Base system installed successfully${RESET}"
echo -e "${YELLOW}Next steps after reboot:${RESET}"
echo "  1. Login as: $USERNAME / $USER_PASS"
echo "  2. Run:  bash ~/archvm-post-install.sh"
echo ""
echo -e "${CYAN}Rebooting in 5 seconds...${RESET}"
sleep 5
umount -R /mnt
reboot
