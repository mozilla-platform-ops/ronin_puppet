#!/usr/bin/env bash

set -e

# enables the gnome-session-x11 systemd service

sudo -u cltbld XDG_RUNTIME_DIR="/run/user/$(id -u cltbld)" systemctl --user daemon-reload
sudo -u cltbld XDG_RUNTIME_DIR="/run/user/$(id -u cltbld)" systemctl --user enable --now gnome-session-x11.service
