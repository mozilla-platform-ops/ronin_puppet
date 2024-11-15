#!/bin/bash

# Set environment variables explicitly
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/puppetlabs/bin:/Library/Frameworks/Python.framework/Versions/3.11/bin:/usr/local/munki
export HOME=/Users/relops
export SHELL=/bin/bash
export LANG=en_US.UTF-8

if command -v directory_cleaner &> /dev/null
then
    directory_cleaner -c /opt/directory_cleaner/configs/config.toml --remove-empty-directories /opt/worker/downloads
    directory_cleaner -c /opt/directory_cleaner/configs/config.toml --remove-empty-directories /Users/cltbld/Library/Caches/Mozilla/updates/opt/worker/tasks/
    directory_cleaner -c /opt/directory_cleaner/configs/config.toml --remove-empty-directories /Users/cltbld/Downloads
fi
