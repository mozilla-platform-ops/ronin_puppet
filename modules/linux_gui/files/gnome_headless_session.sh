#!/bin/bash

# instead of using /etc/X11/Xsession, craft our own session script

# get uid of script
SCRIPT_UID=$(id -u)
export SCRIPT_UID

# Set env vars if not already set
export DISPLAY=${DISPLAY:-:0}
export XAUTHORITY=${XAUTHORITY:-$HOME/.Xauthority}
export XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-x11}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$SCRIPT_UID}
export DESKTOP_SESSION=${DESKTOP_SESSION:-ubuntu}
export XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-ubuntu:GNOME}
export GNOME_SHELL_SESSION_MODE=${GNOME_SHELL_SESSION_MODE:-ubuntu}

# Optional: clean up old state
rm -f "$XDG_RUNTIME_DIR/gnome-shell-disable-extensions"

# Preload xsettingsd (simpler than gsd-xsettings in headless mode)
# xsettingsd &
# note: didn't work for replacing `gsd-xsettings`

# Start required pieces
/usr/libexec/gsd-xsettings --replace &
/usr/libexec/gsd-power &
/usr/libexec/gsd-media-keys &
/usr/libexec/gsd-usb-protection &
/usr/libexec/gsd-color &

# Start GNOME
# dbus-run is handled by systemd-run a level up
# exec dbus-run-session -- gnome-session --session=ubuntu
#
exec gnome-session --session=ubuntu
