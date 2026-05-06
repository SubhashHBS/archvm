#!/usr/bin/env bash
# ============================================================
#  ArchVM Post-Install — Desktop Setup
#  Dark · Performance · VMware
#  Phase 2: DE, Theming, Apps
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
info()   { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()     { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()   { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
banner() { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════${RESET}\n${BOLD}${CYAN}  $*${RESET}\n${BOLD}${CYAN}══════════════════════════════════════${RESET}\n"; }

banner "ArchVM — Desktop Configuration"

HOME_DIR="$HOME"
CONFIG="$HOME_DIR/.config"
mkdir -p "$CONFIG"

# ─── AUR Helper (yay) ───────────────────────────────────────
banner "Installing AUR Helper (yay)"
if ! command -v yay &>/dev/null; then
  git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
  cd /tmp/yay-bin && makepkg -si --noconfirm
  cd ~
  ok "yay installed"
else
  ok "yay already present"
fi

# ─── Xorg + i3 Desktop Stack ────────────────────────────────
banner "Installing Display Stack"
sudo pacman -S --noconfirm \
  xorg-server xorg-xinit xorg-xrandr xorg-xset xorg-xsetroot \
  i3-wm i3status i3blocks \
  dmenu rofi \
  picom \
  nitrogen \
  dunst \
  lxappearance \
  xdotool xclip xsel \
  numlockx \
  xss-lock i3lock

ok "Xorg + i3 installed"

# ─── Display Manager (SDDM dark) ────────────────────────────
banner "Installing SDDM"
sudo pacman -S --noconfirm sddm qt5-graphicaleffects qt5-svg qt5-quickcontrols2
yay -S --noconfirm sddm-theme-sugar-dark 2>/dev/null || true
sudo systemctl enable sddm

sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/archvm.conf > /dev/null <<'EOF'
[Theme]
Current=sugar-dark

[General]
Numlock=on
InputMethod=

[Users]
DefaultPath=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin
MinimumUid=1000
MaximumUid=60000
HideUsers=
HideShells=
RememberLastUser=true
RememberLastSession=true
EOF
ok "SDDM configured"

# ─── Applications ───────────────────────────────────────────
banner "Installing Applications"
sudo pacman -S --noconfirm \
  alacritty \
  thunar thunar-archive-plugin thunar-volman \
  gvfs gvfs-mtp \
  firefox \
  code \
  vlc \
  gimp \
  flameshot \
  qbittorrent \
  libreoffice-fresh \
  ranger \
  cava \
  playerctl \
  pavucontrol \
  blueman \
  polkit-gnome \
  xdg-user-dirs \
  ttf-jetbrains-mono-nerd \
  ttf-fira-code \
  noto-fonts noto-fonts-emoji \
  papirus-icon-theme

yay -S --noconfirm \
  catppuccin-gtk-theme-mocha \
  catppuccin-cursors-mocha \
  ttf-meslo-nerd \
  pfetch \
  pipes.sh \
  cmatrix 2>/dev/null || warn "Some AUR packages failed; continuing"

ok "Applications installed"

# ─── Alacritty Config ───────────────────────────────────────
banner "Configuring Alacritty (Terminal)"
mkdir -p "$CONFIG/alacritty"
cat > "$CONFIG/alacritty/alacritty.toml" <<'EOF'
[window]
padding = { x = 16, y = 12 }
decorations = "none"
opacity = 0.94
blur = true
startup_mode = "Windowed"
title = "Alacritty"

[scrolling]
history = 10000
multiplier = 3

[font]
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
bold   = { family = "JetBrainsMono Nerd Font", style = "Bold" }
italic = { family = "JetBrainsMono Nerd Font", style = "Italic" }
size   = 12.0

[colors.primary]
background = "#1e1e2e"
foreground = "#cdd6f4"

[colors.cursor]
text   = "#1e1e2e"
cursor = "#f5e0dc"

[colors.normal]
black   = "#45475a"
red     = "#f38ba8"
green   = "#a6e3a1"
yellow  = "#f9e2af"
blue    = "#89b4fa"
magenta = "#f5c2e7"
cyan    = "#94e2d5"
white   = "#bac2de"

[colors.bright]
black   = "#585b70"
red     = "#f38ba8"
green   = "#a6e3a1"
yellow  = "#f9e2af"
blue    = "#89b4fa"
magenta = "#f5c2e7"
cyan    = "#94e2d5"
white   = "#a6adc8"

[env]
TERM = "xterm-256color"

[keyboard]
bindings = [
  { key = "V",      mods = "Control|Shift", action = "Paste" },
  { key = "C",      mods = "Control|Shift", action = "Copy" },
  { key = "Plus",   mods = "Control",       action = "IncreaseFontSize" },
  { key = "Minus",  mods = "Control",       action = "DecreaseFontSize" },
  { key = "Key0",   mods = "Control",       action = "ResetFontSize" },
]
EOF
ok "Alacritty configured"

# ─── i3 Config ──────────────────────────────────────────────
banner "Configuring i3"
mkdir -p "$CONFIG/i3"
cat > "$CONFIG/i3/config" <<'EOF'
# ArchVM i3 Config — Catppuccin Mocha Dark
# Mod key: Super
set $mod Mod4
set $alt Mod1

# Font
font pango:JetBrainsMono Nerd Font 10

# Terminal
set $term alacritty
set $browser firefox
set $files thunar
set $launcher rofi -show drun

# Startup
exec --no-startup-id picom --config ~/.config/picom/picom.conf
exec --no-startup-id nitrogen --restore
exec --no-startup-id dunst
exec --no-startup-id /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec --no-startup-id numlockx on
exec --no-startup-id xset r rate 300 50
exec --no-startup-id NetworkManager-applet
exec_always --no-startup-id xsetroot -cursor_name left_ptr

# Catppuccin Mocha Colors
set $rosewater  #f5e0dc
set $flamingo   #f2cdcd
set $pink       #f5c2e7
set $mauve      #cba6f7
set $red        #f38ba8
set $maroon     #eba0ac
set $peach      #fab387
set $yellow     #f9e2af
set $green      #a6e3a1
set $teal       #94e2d5
set $sky        #89dceb
set $sapphire   #74c7ec
set $blue       #89b4fa
set $lavender   #b4befe
set $text       #cdd6f4
set $subtext1   #bac2de
set $surface2   #585b70
set $surface0   #313244
set $base       #1e1e2e
set $mantle     #181825
set $crust      #11111b

# Window borders
default_border pixel 2
default_floating_border pixel 2
hide_edge_borders smart
gaps inner 8
gaps outer 4

# Colors:               border    bg        text      indicator child_border
client.focused          $mauve    $base     $text     $mauve    $mauve
client.focused_inactive $surface0 $base     $subtext1 $surface2 $surface0
client.unfocused        $surface0 $mantle   $subtext1 $surface2 $surface0
client.urgent           $red      $base     $red      $red      $red

# Keybindings
bindsym $mod+Return       exec $term
bindsym $mod+d            exec $launcher
bindsym $mod+e            exec $files
bindsym $mod+w            exec $browser
bindsym $mod+Shift+q      kill
bindsym $mod+Shift+r      restart
bindsym $mod+Shift+e      exec i3-msg exit
bindsym $mod+l            exec i3lock -c 11111b
bindsym Print             exec flameshot gui

# Focus
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right
bindsym $mod+Left  focus left
bindsym $mod+Down  focus down
bindsym $mod+Up    focus up
bindsym $mod+Right focus right

# Move
bindsym $mod+Shift+h move left
bindsym $mod+Shift+j move down
bindsym $mod+Shift+k move up
bindsym $mod+Shift+l move right
bindsym $mod+Shift+Left  move left
bindsym $mod+Shift+Down  move down
bindsym $mod+Shift+Up    move up
bindsym $mod+Shift+Right move right

# Resize
bindsym $mod+r mode "resize"
mode "resize" {
  bindsym h resize shrink width  10 px or 10 ppt
  bindsym j resize grow   height 10 px or 10 ppt
  bindsym k resize shrink height 10 px or 10 ppt
  bindsym l resize grow   width  10 px or 10 ppt
  bindsym Return mode "default"
  bindsym Escape mode "default"
}

# Layout
bindsym $mod+s layout stacking
bindsym $mod+t layout tabbed
bindsym $mod+y layout toggle split
bindsym $mod+f fullscreen toggle
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle
bindsym $mod+a focus parent

# Workspaces
set $ws1 "1 "
set $ws2 "2 "
set $ws3 "3 "
set $ws4 "4 "
set $ws5 "5 "
set $ws6 "6 "
set $ws7 "7 "
set $ws8 "8 "
set $ws9 "9 "
set $ws10 "10 "

bindsym $mod+1 workspace $ws1
bindsym $mod+2 workspace $ws2
bindsym $mod+3 workspace $ws3
bindsym $mod+4 workspace $ws4
bindsym $mod+5 workspace $ws5
bindsym $mod+6 workspace $ws6
bindsym $mod+7 workspace $ws7
bindsym $mod+8 workspace $ws8
bindsym $mod+9 workspace $ws9
bindsym $mod+0 workspace $ws10

bindsym $mod+Shift+1 move container to workspace $ws1
bindsym $mod+Shift+2 move container to workspace $ws2
bindsym $mod+Shift+3 move container to workspace $ws3
bindsym $mod+Shift+4 move container to workspace $ws4
bindsym $mod+Shift+5 move container to workspace $ws5
bindsym $mod+Shift+6 move container to workspace $ws6
bindsym $mod+Shift+7 move container to workspace $ws7
bindsym $mod+Shift+8 move container to workspace $ws8
bindsym $mod+Shift+9 move container to workspace $ws9
bindsym $mod+Shift+0 move container to workspace $ws10

# Media
bindsym XF86AudioPlay  exec playerctl play-pause
bindsym XF86AudioNext  exec playerctl next
bindsym XF86AudioPrev  exec playerctl previous
bindsym XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +5%
bindsym XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -5%
bindsym XF86AudioMute        exec pactl set-sink-mute @DEFAULT_SINK@ toggle

# Bar (i3status)
bar {
  position top
  status_command i3status --config ~/.config/i3/i3status.conf
  font pango:JetBrainsMono Nerd Font 10
  separator_symbol "  "
  colors {
    background         $base
    statusline         $text
    separator          $surface2
    focused_workspace  $base $mauve    $base
    active_workspace   $base $surface0 $subtext1
    inactive_workspace $base $base     $subtext1
    urgent_workspace   $base $red      $base
  }
}
EOF
ok "i3 configured"

# ─── i3status ────────────────────────────────────────────────
cat > "$CONFIG/i3/i3status.conf" <<'EOF'
general {
  colors = true
  interval = 5
  color_good     = "#a6e3a1"
  color_degraded = "#f9e2af"
  color_bad      = "#f38ba8"
}

order += "cpu_usage"
order += "memory"
order += "disk /"
order += "net_rate"
order += "tztime local"

cpu_usage {
  format = " CPU %usage"
  degraded_threshold = 50
  bad_threshold = 85
}

memory {
  format = " RAM %used/%total"
  threshold_degraded = "2G"
  format_degraded = " RAM LOW: %free"
}

disk "/" {
  format = " %avail"
}

net_rate {
  format = " %bitrate_rx  %bitrate_tx"
}

tztime local {
  format = " %a %d %b  %H:%M"
}
EOF

# ─── Picom Config ────────────────────────────────────────────
banner "Configuring Picom (Compositor)"
mkdir -p "$CONFIG/picom"
cat > "$CONFIG/picom/picom.conf" <<'EOF'
# ArchVM Picom — Performance-tuned compositor

# ── Shadows ───────────────────────────────────
shadow = true;
shadow-radius = 16;
shadow-opacity = 0.5;
shadow-offset-x = -8;
shadow-offset-y = -8;
shadow-exclude = [
  "name = 'Notification'",
  "class_g = 'Conky'",
  "class_g ?= 'Notify-osd'",
  "_GTK_FRAME_EXTENTS@:c"
];

# ── Fading ────────────────────────────────────
fading = true;
fade-in-step  = 0.05;
fade-out-step = 0.05;
fade-delta    = 6;

# ── Transparency ──────────────────────────────
inactive-opacity = 0.90;
active-opacity   = 1.0;
frame-opacity    = 1.0;
inactive-opacity-override = false;
opacity-rule = [
  "94:class_g = 'Alacritty'",
  "100:class_g = 'firefox'",
  "100:class_g = 'Code'",
];

# ── Blur ──────────────────────────────────────
blur-method = "dual_kawase";
blur-strength = 5;
blur-background = true;
blur-background-frame = true;
blur-background-fixed = false;

# ── Corners ───────────────────────────────────
corner-radius = 8;
rounded-corners-exclude = [
  "window_type = 'dock'",
  "window_type = 'desktop'"
];

# ── Backend ───────────────────────────────────
backend = "glx";
vsync = true;
glx-no-stencil = true;
glx-copy-from-front = false;
use-damage = true;

# ── Performance ───────────────────────────────
unredir-if-possible = true;
unredir-if-possible-delay = 0;
detect-rounded-corners = true;
detect-client-opacity = true;
detect-transient = true;
detect-client-leader = true;
EOF
ok "Picom configured"

# ─── Rofi Config ────────────────────────────────────────────
banner "Configuring Rofi (Launcher)"
mkdir -p "$CONFIG/rofi"
cat > "$CONFIG/rofi/config.rasi" <<'EOF'
configuration {
  modi: "drun,run,window";
  show-icons: true;
  drun-display-format: "{name}";
  display-drun: "Apps";
  display-run: "Run";
  display-window: "Windows";
  terminal: "alacritty";
}

* {
  bg0:    #1e1e2e;
  bg1:    #313244;
  bg2:    #585b70;
  fg0:    #cdd6f4;
  fg1:    #bac2de;
  accent: #cba6f7;
  red:    #f38ba8;

  background-color: transparent;
  text-color:       @fg0;
}

window {
  background-color: @bg0;
  border:           2px;
  border-color:     @accent;
  border-radius:    12px;
  padding:          12px;
  width:            480px;
}

mainbox {
  background-color: transparent;
  children: [ inputbar, listview ];
  spacing: 8px;
}

inputbar {
  background-color: @bg1;
  border-radius:    8px;
  padding:          10px 14px;
  children:         [ prompt, entry ];
  spacing:          8px;
}

prompt {
  background-color: transparent;
  text-color:       @accent;
  font:             "JetBrainsMono Nerd Font 11";
}

entry {
  background-color: transparent;
  text-color:       @fg0;
  placeholder:      "Search...";
  placeholder-color: @fg1;
}

listview {
  background-color: transparent;
  columns:          1;
  lines:            8;
  spacing:          4px;
  scrollbar:        false;
}

element {
  background-color: transparent;
  border-radius:    6px;
  padding:          8px 12px;
  spacing:          10px;
  children:         [ element-icon, element-text ];
}

element selected {
  background-color: @bg1;
  text-color:       @accent;
}

element-icon {
  size:             24px;
}

element-text {
  background-color: transparent;
  text-color:       inherit;
}
EOF
ok "Rofi configured"

# ─── Dunst (Notifications) ──────────────────────────────────
mkdir -p "$CONFIG/dunst"
cat > "$CONFIG/dunst/dunstrc" <<'EOF'
[global]
  monitor = 0
  follow = mouse
  width = 340
  height = 200
  origin = top-right
  offset = 12x12
  scale = 0
  notification_limit = 5
  progress_bar = true
  progress_bar_height = 6
  progress_bar_frame_width = 1
  progress_bar_min_width = 150
  progress_bar_max_width = 300
  indicate_hidden = yes
  transparency = 10
  separator_height = 2
  padding = 12
  horizontal_padding = 14
  text_icon_padding = 0
  frame_width = 2
  frame_color = "#cba6f7"
  separator_color = frame
  sort = yes
  idle_threshold = 120
  font = JetBrainsMono Nerd Font 10
  line_height = 0
  markup = full
  format = "<b>%s</b>\n%b"
  alignment = left
  show_age_threshold = 60
  ellipsize = middle
  stack_duplicates = true
  hide_duplicate_count = false
  show_indicators = yes
  icon_position = left
  min_icon_size = 0
  max_icon_size = 32
  sticky_history = yes
  history_length = 20
  browser = /usr/bin/firefox
  always_run_script = true
  corner_radius = 8
  timeout = 5

[urgency_low]
  background = "#1e1e2e"
  foreground = "#cdd6f4"
  timeout = 5

[urgency_normal]
  background = "#1e1e2e"
  foreground = "#cdd6f4"
  frame_color = "#89b4fa"
  timeout = 8

[urgency_critical]
  background = "#1e1e2e"
  foreground = "#f38ba8"
  frame_color = "#f38ba8"
  timeout = 0
EOF
ok "Dunst configured"

# ─── ZSH Config ─────────────────────────────────────────────
banner "Configuring ZSH + Oh My Zsh"
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || warn "OMZ install failed"
fi

git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" 2>/dev/null || true

cat > "$HOME/.zshrc" <<'ZSHRC'
# ArchVM .zshrc

# Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  sudo
  zsh-autosuggestions
  zsh-syntax-highlighting
  colored-man-pages
  history-substring-search
  command-not-found
  fzf
)

source $ZSH/oh-my-zsh.sh

# ── Aliases ─────────────────────────────────
alias ls='eza --icons --group-directories-first'
alias ll='eza -lha --icons --group-directories-first'
alias lt='eza --tree --icons -L 2'
alias cat='bat --style=auto'
alias grep='grep --color=auto'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias top='btop'
alias vi='vim'
alias update='sudo pacman -Syu && yay -Syu'
alias cleanup='sudo pacman -Rns $(pacman -Qtdq) 2>/dev/null; paccache -r'
alias psi='sudo pacman -S'
alias psr='sudo pacman -Rns'
alias pss='pacman -Ss'
alias psi='pacman -Si'
alias reload='source ~/.zshrc'
alias dotfiles='cd ~/.config && ls'
alias i3conf='vim ~/.config/i3/config'
alias myip='curl -s ifconfig.me'
alias ports='ss -tulpn'
alias mem='free -h && vmstat -s'
alias cpu='cat /proc/cpuinfo | grep "model name" | uniq'

# ── Environment ─────────────────────────────
export EDITOR=vim
export VISUAL=vim
export BROWSER=firefox
export TERM=xterm-256color
export PATH="$HOME/.local/bin:$PATH"
export FZF_DEFAULT_OPTS='--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8'

# ── Welcome ─────────────────────────────────
pfetch 2>/dev/null || neofetch

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
ZSHRC
ok "ZSH configured"

# ─── GTK Theme ──────────────────────────────────────────────
banner "Setting Dark GTK Theme"
mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"

cat > "$HOME/.config/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=catppuccin-mocha-mauve-standard+default
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=catppuccin-mocha-dark-cursors
gtk-font-name=Noto Sans 10
gtk-application-prefer-dark-theme=true
gtk-button-images=0
gtk-menu-images=0
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintfull
gtk-xft-rgba=rgb
EOF

cat > "$HOME/.config/gtk-4.0/settings.ini" <<'EOF'
[Settings]
gtk-application-prefer-dark-theme=true
gtk-theme-name=catppuccin-mocha-mauve-standard+default
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=catppuccin-mocha-dark-cursors
gtk-font-name=Noto Sans 10
EOF

# Xresources
cat > "$HOME/.Xresources" <<'EOF'
! Catppuccin Mocha
*.foreground:  #cdd6f4
*.background:  #1e1e2e
*.cursorColor: #f5e0dc
*.color0:  #45475a
*.color1:  #f38ba8
*.color2:  #a6e3a1
*.color3:  #f9e2af
*.color4:  #89b4fa
*.color5:  #f5c2e7
*.color6:  #94e2d5
*.color7:  #bac2de
*.color8:  #585b70
*.color9:  #f38ba8
*.color10: #a6e3a1
*.color11: #f9e2af
*.color12: #89b4fa
*.color13: #f5c2e7
*.color14: #94e2d5
*.color15: #a6adc8

Xcursor.theme: catppuccin-mocha-dark-cursors
Xcursor.size:  24
Xft.dpi:       96
Xft.antialias: true
Xft.hinting:   true
Xft.rgba:      rgb
Xft.hintstyle: hintfull
EOF

# xinitrc
cat > "$HOME/.xinitrc" <<'EOF'
#!/bin/sh
xrdb -merge ~/.Xresources
xsetroot -cursor_name left_ptr
numlockx on &
exec i3
EOF
chmod +x "$HOME/.xinitrc"
ok "GTK theme set"

# ─── Neofetch Config ────────────────────────────────────────
mkdir -p "$HOME/.config/neofetch"
cat > "$HOME/.config/neofetch/config.conf" <<'EOF'
print_info() {
    info title
    info underline
    info "OS"         distro
    info "Kernel"     kernel
    info "Shell"      shell
    info "DE/WM"      wm
    info "Terminal"   term
    info "CPU"        cpu
    info "Memory"     memory
    info "Uptime"     uptime
    info "Packages"   packages
    info "Disk"       disk
    info cols
}

colors=(4 5 6 2 3 1)
bold="on"
underline_enabled="on"
separator=":"
color_blocks="on"
block_width=3
block_height=1
col_offset="auto"
image_backend="ascii"
ascii_distro="arch"
ascii_colors=(4 5 6 2 3 1)
ascii_bold="on"
EOF

# ─── VMware DPI Fix ─────────────────────────────────────────
banner "VMware Optimizations"
sudo tee /etc/X11/xorg.conf.d/10-vmware.conf > /dev/null <<'EOF'
Section "Device"
  Identifier "VMware SVGA"
  Driver "vmware"
  Option "RenderAccel" "true"
EndSection

Section "Monitor"
  Identifier "Default"
  Option "DPMS" "off"
EndSection

Section "Screen"
  Identifier "Default Screen"
  Device "VMware SVGA"
  Monitor "Default"
  DefaultDepth 24
  SubSection "Display"
    Depth    24
    Modes    "1920x1080" "1680x1050" "1600x900" "1366x768"
  EndSubSection
EndSection
EOF
ok "VMware Xorg config set"

# ─── Finalize ────────────────────────────────────────────────
banner "Running Performance Tweaks"
bash "$HOME/archvm-performance.sh" 2>/dev/null || warn "Performance script skipped"

banner "Setup Complete!"
echo -e "${GREEN}✔ ArchVM Dark Desktop configured!${RESET}"
echo ""
echo -e "  ${CYAN}Reboot now:${RESET}  sudo reboot"
echo -e "  ${CYAN}Login via SDDM${RESET} and i3 starts automatically"
echo -e "  ${CYAN}Mod key is Super (Win)${RESET}"
echo -e "  ${CYAN}Super+Enter${RESET}  = Terminal"
echo -e "  ${CYAN}Super+d${RESET}      = App Launcher"
echo -e "  ${CYAN}Super+w${RESET}      = Browser"
echo ""
