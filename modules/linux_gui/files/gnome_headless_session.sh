#!/bin/bash

# instead of using /etc/X11/Xsession, craft our own session script

# get uid of script
SCRIPT_UID=""
SCRIPT_UID=$(id -u)
export SCRIPT_UID

# set env vars
export DISPLAY=:0
export XDG_SESSION_TYPE=x11
export XDG_RUNTIME_DIR=/run/user/$SCRIPT_UID
# TODO: needed?
export DESKTOP_SESSION=ubuntu

# Optional: clean up old state
rm -f "$XDG_RUNTIME_DIR/gnome-shell-disable-extensions"

# Start required pieces
/usr/libexec/gsd-xsettings --replace &
/usr/libexec/gsd-power &
/usr/libexec/gsd-media-keys &
/usr/libexec/gsd-usb-protection &
/usr/libexec/gsd-color &

# Start GNOME
exec dbus-run-session -- gnome-session --session=ubuntu
