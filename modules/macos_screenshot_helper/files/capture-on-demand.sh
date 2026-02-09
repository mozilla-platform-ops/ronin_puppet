#!/bin/bash

# Screenshot configuration
OUTPUT_DIR="/Users/cltbld/Desktop"
FILENAME="screenshot-$(date +%Y%m%d-%H%M%S).png"

# Ensure output directory exists
mkdir -p "${OUTPUT_DIR}"

# Take screenshot
/usr/sbin/screencapture -C -x -t png "${OUTPUT_DIR}/${FILENAME}"

# Log the capture
echo "$(date): Screenshot saved to ${OUTPUT_DIR}/${FILENAME}" >> /tmp/screenshot-capture.log
