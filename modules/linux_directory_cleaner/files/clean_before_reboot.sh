#!/bin/bash

if command -v directory_cleaner &> /dev/null
then
    directory_cleaner -c /opt/directory_cleaner/configs/config.toml --remove-empty-directories /home/cltbld/downloads
fi
