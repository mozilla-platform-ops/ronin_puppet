#!/bin/bash

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="/Users/cltbld/Desktop"
FILENAME="ci_screenshot_${TIMESTAMP}.png"

/usr/sbin/screencapture -C -x -t png "${OUTPUT_DIR}/${FILENAME}"
