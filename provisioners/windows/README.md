# Ronin Windows Bootstrapping

There should be a bootstrap script for each workerType.

The script will set the unique worker type Generic-worker configuration. As well as the behavior of future use of Puppet on the node, and determine where the Puppet code is cloned from.

There a re three stages to the bootstrap script.

## Bootstrap Stages

**Setup**:

Set registry settings  to dictate Workertype and Puppet schedule task behavior.

   * HKLM:\SOFTWARE\Mozilla\ ronin_puppet

     - inmutable (true/false)
     - runtosuccess  (true/false)
     - last_run_exit  (starts at 0)
     - bootstrap_stage  (sets to setup)
     - workerType  (set desire workerType)
     - role  (use to determine which Puppet role will be applied)

Set to determine which github repository and revision.

   * HKLM:\SOFTWARE\Mozilla\ ronin_puppet\source

     - Organisation
     - Repository
     - Revision

  * Download the latest version of itself, and  create a schedule task to continue to run after next reboot.
  * Perform initial Git clone.
  * Generate a node.pp manifest for node Puppet definition.

**Inprogress**:

   * Initiate Puppet apply.
   * Determine if the Puppet apply was successful or not.
   * Reboot and run Puppet apply until success.

**Complete**:

  * Once the inprogress stage determines a successful run,:
   * Deletion of bootstrap files
   * Deletion of bootstrap schedule task

After completion of botostrap script future initiations of Puppet apply, if configured,  will be managed by the maintainsystem schedule task.

## Prerequisites:
Prerequisites for bootstrapping (Currently hardware nodes are prepared for bootstrap through an MDT task sequence)

* Installation of hardware drivers such as network and graphics.
* Installation and configuration of Nxlog.
* Installation of Git, Puppet, and R10k
The initial download and schedule task for the bootstrap script

TODO: add a shared private GPG key per workerType



## WorkerType explanation:
### HARDWARE (incomplete list)
**gecko-t-win10-64-hw**  - Production worker type for HP Moonshot blades

**gecko-t-win10-64-ht**    - Testing/Development worker type for HP Moonshot blades

**gecko-t-win10-64-hbeta**    - Beta worker type for HP Moonshot blades

**gecko-t-win10-64-ux**    -  Production worker type for ACER consumer grade hardware

**gecko-t-win10-64-ut**    -  Testing/Development worker type for ACER consumer grade hardware
