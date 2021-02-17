#!/usr/bin/env bash

set -e
set -x

/usr/local/bin/run-start-worker.sh /etc/start-worker.yml 2>&1 | logger -t run-start-worker -s
