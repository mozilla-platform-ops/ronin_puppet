#!/bin/bash

# Set environment variables explicitly
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/puppetlabs/bin:/Library/Frameworks/Python.framework/Versions/3.11/bin:/usr/local/munki
export HOME=/Users/relops
export SHELL=/bin/bash
export LANG=en_US.UTF-8

if command -v directory_cleaner &> /dev/null
then
    directory_cleaner -c /opt/directory_cleaner/configs/config.toml --remove-empty-directories /Users/cltbld/Library/Caches/Mozilla/updates/opt/worker/tasks/
    directory_cleaner -c /opt/directory_cleaner/configs/config.toml --remove-empty-directories /Users/cltbld/Downloads
    directory_cleaner -c /opt/directory_cleaner/configs/config.toml --remove-empty-directories /Users/cltbld/Desktop
    directory_cleaner -c /opt/directory_cleaner/configs/config.toml --remove-empty-directories /Users/cltbld/Library/Application\ Support/Firefox/Crash\ Reports
    directory_cleaner -c /opt/directory_cleaner/configs/config.toml --remove-empty-directories /var/db/oah
fi

# Clean coresymbolicationd cache if it exceeds 5GB
CORESYM_DATA="/System/Library/Caches/com.apple.coresymbolicationd/data"
CORESYM_THRESHOLD=$((5 * 1024 * 1024 * 1024))  # 5GB in bytes
if [ -f "$CORESYM_DATA" ]; then
    CORESYM_SIZE=$(stat -f%z "$CORESYM_DATA")
    if [ "$CORESYM_SIZE" -gt "$CORESYM_THRESHOLD" ]; then
        echo "coresymbolicationd data file is ${CORESYM_SIZE} bytes, exceeds threshold, removing"
        sudo rm -f "$CORESYM_DATA"
        sudo killall coresymbolicationd 2>/dev/null || true
    fi
fi
