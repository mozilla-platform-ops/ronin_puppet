#!/bin/bash

# Script will look for VMs up for a 3 hours in more
# and then will look worker and find last task

echo Setting up.

export TASKCLUSTER_ROOT_URL='https://firefox-ci-tc.services.mozilla.com/'
echo Get Taskcluster credentials
eval "$(taskcluster signin)"
echo Logging into Azure
pwsh -command az login

work_dir=${RANDOM}_dir
echo working dir is "$work_dir"
mkdir "$work_dir"

echo Searching for questionable VMs
pwsh ./get_vms.ps1 "$work_dir"

echo Checking questionable VMs\' tasks
./last_task_check.sh -d "$work_dir"

echo cleaning up
rm -fr "$work_dir"
