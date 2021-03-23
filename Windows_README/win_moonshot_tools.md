# Moonshot Windows Workers Management Tools


##### Prerequisites
* VPN connection to MDC1.
* The scripts from [Win Maintenance module](https://github.com/mozilla-platform-ops/ronin_puppet/tree/master/modules/win_maintenance) locally on the worker.
* WinAudit ssh key from Relops sops (These scripts will ssh into WIndows workers, Moonshot chassis, or both).
* The [WinAudit public key](https://github.com/mozilla-platform-ops/ronin_puppet/blob/d28d9a04fd44648e6e131a1b822cfd456427b31e/data/os/Windows.yaml#L53) in the local administrator's known hos file.

##### Limitations
* These scripts operates under the assumption that IP addresses and host names will have static values. Any changes will need to be addressed affecting those two items will need to be addressed for the scripts to work.
* When worker-runner is implemented the scripts will need to be updated.

If a worker is rebooted during deployment, it will boot into a dirty state. This state requires human interaction.

### audit_recover.sh

This script will ssh to the specified host and will execute [worker_status.ps1](https://github.com/mozilla-platform-ops/ronin_puppet/blob/master/modules/win_maintenance/files/worker_status.ps1). If the ssh connection fails the assumption is the worker is down. If the local script is missing or Powershell hangs, the assumption is the worker is misconfigured. If ssh succeeds and the script is ran, it will then check if the worker is configured to be in production and if the generic-worker is up and running. The Powershell script will then hand and exit code back to the main script.

The main script will then wait 30 minutes and recheck any workers that were not in a known good state. If they are still in a bad state the script will attempt to recover them in the order as follows:

1. A hard reset of the hosting Moonshot cartridge.
1. A final check of the worker's state.
2. Attempt to restore if the worker is up but generic-worker is not up and running.
3. Trigger a redeployment of down nodes. (if specified in the script execution).

After the attempted recovery a summary of non-working nodes will be printed in the local shell the script was executed from. It will also send a log message to Papertrail for each unrecovered and non-production worker. Like `WindowsAudit :: t-w1064-ms-070.wintest.releng.mdc1.mozilla.com. is down and a redeploy has been triggered`.

````
Audit and recover Windows Moonshot workers

SSH needs to be enabled and the worker_status.ps1 must be on the worker
Must have the winaudit ssh key to work

options:

-c | --chassis (n)      Specify a single chassis. Options 1 through 7.
-c | --chassis all      Deploy to all 7 chassis.

To specify a range  of nodes use last octet of the IP address

-s | --start_ip (octet) Specify the beginging of a range
-e | --end_ip (octet)   Specify the end of the range
-r | --redeploy         (y)es or (n)o to redeploy unrecovered nodes. defualt n

-h | --help             Print this Help.

*EXAMPLES*
./audit_recover.sh  -c 1
./audit_recover.sh  -c 1 -r y
./audit_recover.sh  -c all
./audit_recover.sh  -s 2 -e 33
````


### moonshot_deploy.sh

This script will shh to the specify Moonshot chassis, set the specified nodes to pxe boot and reboot them. If a single chassis or all the chassis are specify the script will do a maximum of 15 at a time as not to overwhelm the deployment server. If you using an IP a range to specify which nodes to deploy, it is recommended to not trigger more than 15 at a time for the same reason.

In order for this script to work the deployment share rules.ini needs to have to be configured to skip task sequences selection and pointed to the task sequence ID.

```
[Default]
SkipTaskSequence=YES
TaskSequenceID=WIN10-DC-014
```

```
Deploy Windows Moonshot workers.

This will only work if a default task sequence is set in This will only work if a default task sequence is set in
MDT's rules.ini file.
Must have the relops or winaudit ssh key to work

options:

-c | --chassis (n)      Specify a single chassis. Options 1 through 7.
-c | --chassis all      Deploy to all 7 chassis.

To specify a single node or range use last octet of the IP address

-1 | --1_ip (octet)     Deploy to a single.
-s | --start_ip (octet) Specify the beginging of a range
-e | --end_ip (octent)  Specify the end of the range

-h | --help             Print this Help.

*EXAMPLES*
./moonshot_deploy.sh -c 1
./moonshot_deploy.sh -c all
./moonshot_deploy.sh -s 2 -e 33
```


### reboot_moonshot.sh

This script will ssh to the specified chassis and power down/power up the specified nodes.

```
Reboot Windows Moonshot nodes.

Must have the relops or winaudit ssh key to work

options:

-c | --chassis (n)      Specify a single chassis. Options 1 through 7.
-c | --chassis all      Deploy to all 7 chassis.

To specify a single node or range use last octet of the IP address

-1 | --1_ip (octet)     Deploy to a single.
-s | --start_ip (octet) Specify the beginging of a range
-e | --end_ip (octent)  Specify the end of the range

-h | --help             Print this Help.

*EXAMPLES*
./reboot_moonshot.sh -c 1
./reboot_moonshot.sh -c all
./reboot_moonshot.sh -s 2 -e 33
```

### restore_moonshot.sh
This script will ssh to the specified Windows workers and execute [force_restore.ps1](https://github.com/mozilla-platform-ops/ronin_puppet/blob/master/modules/win_maintenance/files/worker_status.ps1). The Powershell script will set a registry value that will trigger the worker's start up scripts ti initiate a restore on the next reboot and then reboots the worker. It is recommended to use the redeploy script instead of this. The redeploy script is a more sure way to recover workers. However, restoring a worker could be faster and runs no risk of overwhelming the deployment server.

```
Trigger restore for Windows Moonshot workers

SSH needs to be enabled and the force_restore.ps1 must be on the worker
Must have the winaudit ssh key to work

options:

-f | --file  Specify a file containing a list of node IP addresses to be restored
-i | --ip    Specify a single node IP address

-h | --help  Print this Help.

This is mainly part of the audit and recovery script
It can be used independently but concider using the deployment script
