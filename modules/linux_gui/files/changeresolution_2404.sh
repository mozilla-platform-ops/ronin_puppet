#!/bin/bash

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

set -e
set -x

# old (used cvt)
# # 1600x1200 59.87 Hz (CVT 1.92M3) hsync: 74.54 kHz; pclk: 161.00 MHz
# /usr/bin/xrandr -d :0 --newmode "1600x1200_60.00"  161.00  1600 1712 1880 2160  1200 1203 1207 1245 -hsync +vsync
# /usr/bin/xrandr -d :0 --addmode VGA-1 1600x1200_60.00
# /usr/bin/xrandr -d :0 --output VGA-1 --mode "1600x1200_60.00"

# new (using gtf)

# Set the display (ensure you're running under Xorg)
export DISPLAY=:0

# Detect current virtual or physical output (e.g., VGA, HDMI, eDP)
OUTPUT=$(xrandr | grep -oE '^(VIRTUAL|Virtual|Virtual-1|VIRTUAL1|VGA|HDMI|eDP|DP)[^ ]*' | head -n1)

if [ -z "$OUTPUT" ]; then
    echo "No suitable output found."
    exit 1
fi

# Generate the mode using cvt
# CVT_OUTPUT=$(cvt 1600 1200 60 | grep Modeline | sed 's/Modeline //' | sed 's/"//g')
GTF_OUTPUT=$(gtf 1600 1200 60 | grep Modeline | sed 's/Modeline //' | sed 's/"//g')

# Extract the mode name and mode parameters separately
# read MODE_NAME MODE_PARAMS <<< "$CVT_OUTPUT"
MODE_NAME2=$(echo "$GTF_OUTPUT" | awk '{print $1}')
MODE_PARAMS2=$(echo "$GTF_OUTPUT" | cut -d ' ' -f3-)

# echo "cvt: $CVT_OUTPUT"
# echo "gtf: $GTF_OUTPUT"
#exit 0

# Create and apply the mode
xrandr --newmode "$MODE_NAME2" "$MODE_PARAMS2"
xrandr --addmode "$OUTPUT" "$MODE_NAME2"
xrandr --output "$OUTPUT" --crtc 0 --mode "$MODE_NAME2"
