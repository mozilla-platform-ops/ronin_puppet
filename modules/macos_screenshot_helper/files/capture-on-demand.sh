#!/bin/bash
TRIGGER_FILE="/Users/cltbld/.trigger_screenshot"

# Exit immediately if trigger file doesn't exist or is empty
[ -s "${TRIGGER_FILE}" ] || exit 0

OUTPUT_PATH=$(cat "${TRIGGER_FILE}")

# Clear the trigger file up front. The truncation itself fires a WatchPaths
# event, but that re-run sees an empty trigger and exits, so a single request
# can never be captured twice.
: > "${TRIGGER_FILE}"

# Ensure output directory exists
mkdir -p "$(dirname "${OUTPUT_PATH}")"

# Capture to a temp file, then atomically move it into place. The harness
# polls for OUTPUT_PATH to become non-empty, so it must only ever appear once
# fully written -- never as a partial or zero-byte frame.
TMP_PATH="${OUTPUT_PATH}.tmp.$$"
/usr/sbin/screencapture -C -x -t png "${TMP_PATH}"

if [ -s "${TMP_PATH}" ]; then
  mv -f "${TMP_PATH}" "${OUTPUT_PATH}"
  echo "$(date): Screenshot saved to ${OUTPUT_PATH}" >> /tmp/screenshot-capture.log
else
  rm -f "${TMP_PATH}"
  echo "$(date): screencapture produced no output for ${OUTPUT_PATH}" >> /tmp/screenshot-capture.log
fi
