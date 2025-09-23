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
