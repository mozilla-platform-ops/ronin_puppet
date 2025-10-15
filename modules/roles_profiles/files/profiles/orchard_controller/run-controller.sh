#!/bin/bash
# Orchard controller wrapper
# Sets up a clean environment and launches the controller exactly as verified manually.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
export HOME="/var/root"
export ORCHARD_HOME="/opt/orchard"

exec /opt/homebrew/bin/orchard controller run \
     --data-dir=/opt/orchard/data \
     --listen=:6120
