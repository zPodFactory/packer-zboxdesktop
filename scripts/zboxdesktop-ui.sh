#!/usr/bin/env bash
set -euo pipefail

# Install xrdp and a minimal XFCE desktop
apt-get install -y xrdp xfce4 xfce4-terminal

# Enable and start xrdp service
systemctl enable xrdp
systemctl start xrdp

# Set XFCE as the default session for new users
echo "xfce4-session" > /etc/skel/.xsession

# Do not start x11 on boot(graphical.target), keep the multi-user.target
systemctl set-default multi-user.target

# Install chromium browser
apt-get install -y chromium

# Install JetBrainsMono Nerd Font system-wide
FONT_DIR="/usr/share/fonts/JetBrainsMono"
mkdir -p "$FONT_DIR"
cd "$FONT_DIR"

wget -q https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip -O JetBrainsMono.zip
unzip -o JetBrainsMono.zip -d "$FONT_DIR" >/dev/null
rm JetBrainsMono.zip

# Refresh system-wide font cache
fc-cache -fv "$FONT_DIR"

# Install user autostart script zBoxDesktop theming
AUTOSTART_DIR="/etc/xdg/autostart"
mkdir -p "$AUTOSTART_DIR"

cat > "$AUTOSTART_DIR/setup-zboxdesktop-user.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Exec=/usr/local/bin/zboxdesktop_user_setup.sh
Hidden=false
X-GNOME-Autostart-enabled=true
Name=Setup zBoxDesktop User
Comment=Apply zBoxDesktop customization
EOF