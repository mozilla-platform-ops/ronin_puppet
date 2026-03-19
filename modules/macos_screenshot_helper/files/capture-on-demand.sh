#!/bin/bash
TRIGGER_FILE="/Users/cltbld/.trigger_screenshot"

# Exit immediately if trigger file doesn't exist or is empty
[ -s "${TRIGGER_FILE}" ] || exit 0

OUTPUT_PATH=$(cat "${TRIGGER_FILE}")

# Ensure output directory exists
mkdir -p "$(dirname "${OUTPUT_PATH}")"

# Take screenshot
/usr/sbin/screencapture -C -x -t png "${OUTPUT_PATH}"

# Log the capture
echo "$(date): Screenshot saved to ${OUTPUT_PATH}" >> /tmp/screenshot-capture.log

# Clear the trigger file
: > "${TRIGGER_FILE}"
