#!/bin/bash

TRIGGER_FILE="/Users/cltbld/.trigger_screenshot"

# Read the output path from the trigger file if it exists and is not empty
if [ -s "${TRIGGER_FILE}" ]; then
    OUTPUT_PATH=$(cat "${TRIGGER_FILE}")
else
    # Fallback to default location
    OUTPUT_DIR="/Users/cltbld/Desktop"
    FILENAME="screenshot-$(date +%Y%m%d-%H%M%S).png"
    OUTPUT_PATH="${OUTPUT_DIR}/${FILENAME}"
fi

# Ensure output directory exists
mkdir -p "$(dirname "${OUTPUT_PATH}")"

# Take screenshot
/usr/sbin/screencapture -C -x -t png "${OUTPUT_PATH}"

# Log the capture
echo "$(date): Screenshot saved to ${OUTPUT_PATH}" >> /tmp/screenshot-capture.log

# Clear the trigger file
: > "${TRIGGER_FILE}"
