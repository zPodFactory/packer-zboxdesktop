#!/usr/bin/env bash
set -euo pipefail

MARKER="$HOME/.config/.zboxdesktop-user-done"
if [[ -f "$MARKER" ]]; then
    echo "zBoxDesktop user setup already done"
    exit 0
fi

BACKGROUND="#1e1e2e"
FOREGROUND="#cdd6f4"
CURSOR="#cdd6f4"
SELECTION="#f5e0dc"
PALETTE="#1e1e2e;#f38ba8;#a6e3a1;#f9e2af;#89b4fa;#f5c2e7;#94e2d5;#bac2de;#585b70;#f38ba8;#a6e3a1;#f9e2af;#89b4fa;#f5c2e7;#94e2d5;#cdd6f4"
FONT="JetBrainsMono Nerd Font Mono 12"

xfconf-query -c xfce4-terminal -p /color-background --create -t string -s "$BACKGROUND" || true
xfconf-query -c xfce4-terminal -p /color-foreground --create -t string -s "$FOREGROUND" || true
xfconf-query -c xfce4-terminal -p /color-cursor --create -t string -s "$CURSOR" || true
xfconf-query -c xfce4-terminal -p /color-selection --create -t string -s "$SELECTION" || true
xfconf-query -c xfce4-terminal -p /color-palette --create -t string -s "$PALETTE" || true
xfconf-query -c xfce4-terminal -p /color-use-theme --create -t bool -s false || true
xfconf-query -c xfce4-terminal -p /color-bold-is-bright --create -t bool -s true || true
xfconf-query -c xfce4-terminal -p /font-name --create -t string -s "$FONT" || true

# Mark as done
mkdir -p "$HOME/.config"
touch "$MARKER"
echo "zBoxDesktop user setup done"
