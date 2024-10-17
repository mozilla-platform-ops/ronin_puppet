#!/bin/bash

# Log the execution of the script to a file
echo "$(date): Running cleanup script" >> /var/log/clean_before_reboot.log

if command -v directory_cleaner &> /dev/null
then
    directory_cleaner -c /opt/directory_cleaner/configs/config.toml --remove-empty-directories /home/cltbld/downloads
fi

# Log completion of the script
echo "$(date): Cleanup script completed" >> /var/log/clean_before_reboot.log
