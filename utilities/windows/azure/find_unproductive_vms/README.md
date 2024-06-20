# Find Unproductive Azure VMs

`./find_unproductive_vms.sh` will gather the needed Taskclsuster and Azure credentials. Then will start `get_vms.ps1` which will find all VMs have been around for 3 or more hours. That list will then be ran through `last_task_check.sh` to find the latest task performed on the VM. If that task is more than 2.5 hours ago it will be considered unproductive and printed in a final summary. Currently this will only display information and not make any changes to active VMs.

#### Prerequisites
* [Powershell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-7.1) with the Az module available `sudo pwsh -command install-module Az -force`.
* [Jq](https://stedolan.github.io/jq/) installed.
* `get_vms.ps1` and `last_task_check.sh` in the same dir
