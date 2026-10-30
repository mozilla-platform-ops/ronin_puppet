#!/bin/sh
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

set -eu

connector=$(cat /etc/ronin-wayland-connector)
edid=/usr/local/share/ronin-wayland/edid.bin

# Kernel card numbers can change across boots. Match the configured output to
# Intel's PCI vendor ID, then use its stable PCI path for the debugfs override.
attempt=0
while [ "$attempt" -lt 30 ]; do
    intel_output=
    for output in /sys/class/drm/card*-"$connector"; do
        [ -f "$output/device/device/vendor" ] || continue
        [ "$(cat "$output/device/device/vendor")" = 0x8086 ] || continue
        if [ -n "$intel_output" ]; then
            echo "Multiple Intel outputs named $connector; refusing an ambiguous override" >&2
            exit 1
        fi
        intel_output=$output
    done
    if [ -n "$intel_output" ]; then
        pci_device=$(basename "$(readlink -f "$intel_output/device/device")")
        override="/sys/kernel/debug/dri/$pci_device/$connector/edid_override"
        if [ -e "$override" ]; then
            cat "$edid" >"$override"
            case "$connector" in
                HDMI-A-*|DVI-D-*) force=on-digital ;;
                *) force=on ;;
            esac
            printf '%s\n' "$force" >"$intel_output/status"
            if ! grep -Fxq 1600x1200 "$intel_output/modes"; then
                echo "Intel $connector does not advertise 1600x1200 after EDID override" >&2
                exit 1
            fi
            echo "Headless Intel $connector ready on $pci_device"
            exit 0
        fi
    fi
    attempt=$((attempt + 1))
    sleep 1
done

echo "Intel $connector or its EDID override interface did not appear" >&2
exit 1
