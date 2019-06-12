# Ronin Windows Puppet Configuration



## Ronin Windows Bootstrapping

There should be a bootstrap script for each workerType.

The script will set the unique worker type Generic-worker configuration. As well as the behavior of future use of Puppet on the node, and determine where the Puppet code is cloned from.

There a re three stages to the bootstrap script.

### Bootstrap Stages

/provisioners/windows

**Setup**:

Set registry settings  to dictate Workertype and Puppet schedule task behavior.

   * HKLM:\SOFTWARE\Mozilla\ ronin_puppet

     - inmutable (true/false)
     - runtosuccess  (true/false)
     - last_run_exit  (starts at 0)
     - bootstrap_stage  (sets to setup)
     - workerType  (set desire workerType
     - role  (use to determine which Puppet role will be applied)

Set to determine which github repository and revision.

   * HKLM:\SOFTWARE\Mozilla\ ronin_puppet\source

     - Organisation
     - Repository
     - Revision

  * Download the latest version of itself, and  create a schedule task to continue to run after next reboot.
  * Perform initial Git clone.
  * Generate a node.pp manifest for node Puppet definition based off of the workerType registry value.

**Inprogress**:

   * Initiate Puppet apply.
   * Determine if the Puppet apply was successful or not.
   * Reboot and run Puppet apply until success.

**Complete**:

  * Once the inprogress stage determines a successful run,:
   * Deletion of bootstrap files
   * Deletion of bootstrap schedule task


After completion of botostrap script future initiations of Puppet apply, if configured,  will be managed by the maintainsystem schedule task.

### Prerequisites:
Prerequisites for bootstrapping (Currently hardware nodes are prepared for bootstrap through an MDT task sequence)

* Installation of hardware drivers such as network and graphics.
* Installation and configuration of Nxlog.
* Installation of Git, Puppet, and R10K
* * R10k is not required but is in place in case of a future need.
* The initial download and schedule task for the bootstrap script
* Template node file in C:\bootstrap
* For hardware private GPG key per workerType

	  node default {

		include roles_profiles::roles::role

	}

The bootstrap script will replace "include roles_profiles::roles::role" with "include roles_profiles::roles::$workerType" based off of the value of workerType registry value.

The manifest and script can be found under /modules/win_scheduled_tasks.

*NOTE* If there is the need to change the registry values set by the bootstrap the node should reprovisioned.



## Post Bootstrap and Initial Puppet Configuration

Following bootstrapping further management of the repo and the Puppet Configuration is handled by the maintainsystem schedule task. The behavior of the script is dictated by the registry values set by bootstrapping.


## Determination and Flow of Configuration

Ronin Puppet uses Roles & Profiles methodology.

The general flow of configuration is the bootstrap script generates a nodes.pp manifest based off of the workerType registry value. The nodes.pp is called by Puppet and in turns calls the role of the generated workerType value. Note there is one role per workerType. The role then calls multiple profiles. Profiles being manifest which contains data, calculates data, or looks up data, and then calls and passes to classes that perform the configuration.

### Roles

/modules/roles_profiles/manifests/roles

As mentioned above there is one role per workerType. This includes separate  roles between production and testing workerTypes.

	class roles_profiles::roles::geckotwin1064hw {

    # System
    include roles_profiles::profiles::disable_services
    include roles_profiles::profiles::files_system_managment
    include roles_profiles::profiles::firewall
    include roles_profiles::profiles::ntp
    include roles_profiles::profiles::power_management
include roles_profiles::profiles::scheduled_tasks

### Profiles

/modules/roles_profiles/manifests/profiles

This is the only area where POSIX and Windows cross paths. Some of the profiles include all operating systems. Be **EXTRA** careful when updating these manifests.


#### Profile Data

There are four type of data inputted/determined in profiles.

#### Manual Entered Data

Manual enter data. This such as desired application versions.

	$needed_gw_version = '14.1.2'

    class { 'win_generic_worker':
		needed_gw_version              => $needed_gw_version,

This is the least preferable method of inserting data.

#### Facts and Custom Facts

Node specific variables.

	$current_gw_version = $facts['custom_win_genericworker_version']

    class { 'win_generic_worker':
    	 needed_gw_version              => $needed_gw_version,

See below in modules for more information on custom facts.

#### Hiera Data

/data/common.yaml

/data/os/Windows.yaml

Static values stored in Hiera files.

	$ext_pkg_src_loc = lookup('win_ext_pkg_src')
     $tc_pkg_source = "${ext_pkg_src_loc}/taskcluster"

	class { 'win_generic_worker':
    	generic_worker_exe_source      => "${tc_pkg_source}/generic-worker-nativeEngine-windows-amd64-${needed_gw_version}.exe",

 #### Secrets

 \data\secrets\vault.pp

Secrets are looked up the same as other hiera values. However, the secret file itself is not managed by Puppet, but is needed by Puppet. Currently the secret file is copied over during deployment. This will eventually moved to a network service.

For cloud instances this should be handled by the provider secret management.

### Modules

/modules

Classes within modules perform the configuration work. A module should be specific to Windows or POSIX, and Windows modules,name should should be appended  with "win_" for clarification.

#### Win_shared Modules
##### Manifests

/modules/win_shared/manifests/win_ronin_dirs.pp

This handles the creation of directories that is needed for all WIndows nodes to apply Ronin Puppet.

##### Facts.d

modules/win_shared/facts.d

This is a collection of Powershell scripts that produce custom facts.  Powershell produces custom facts by writing a key value pair ("variable=value") to stdout.

> $release_id = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion')
>
> write-host "custom_win_release_id=$release_id"

The above example produces a custom fact with the value for the build version/release ID of the OS.

##### Current Custom Facts

/modules/win_shared/facts.d/facts_win_application_versions.ps1
* custom_win_mozbld_vesion: Value for the current Mozilla Build version.
* custom_win_hg_version: Value for the current Mercurial version

/modules/win_shared/facts.d/facts_win_custom_os.ps1
* custom_win_release_id: Value for the build version/release ID of the OS.
* custom_win_admin_sid:  Value for administrator account ID

/modules/win_shared/facts.d/facts_win_directories.ps1
* custom_win_systemdrive: System drive variable.
* custom_win_system32: System32 directory variable.
* custom_win_programdata: Programdata directory variable.
* custom_win_programfiles: Programfiles directory variable.
* custom_win_programfilesx86: x86 Programfiles directory variable.
* custom_win_roninprogramdata: Ronin subdirectory of programdata variable.
* custom_win_roninsemaphoredir: Semaphore directory variable.
* custom_win_roninslogdir: General logging directory variable.
* custom_win_temp_dir: Temp directory variable.

/modules/win_shared/facts.d/facts_win_generic_worker.ps1
* custom_win_genericworker_version: Value for the version of the currently installed Generic-worker
* custom_win_gw_workerType: value for the node's workerType

/modules/win_shared/facts.d/facts_win_location.ps1
* custom_win_location: Value for node's location. Datacenter, AWS ....
* custom_win_mozspace: Value for the which location for datacenter nodes.

#### Defined Types Used in Modules

There are various defined types in use to reduce code and simplify functions that may require multiple resources or one resource but uses the same attributes.

##### Current Defined Types in Use
######  win_disable_services::disable_service

 ronin_puppet/modules/win_disable_services/manifests/disable_service.pp

 Purpose: To stop/disable service.

 Required parameters:
 * Service passed as title

 class win_disable_services::disable_puppet {

    if $::operatingsystem == 'Windows' {
        win_disable_services::disable_service { 'puppet':
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}

##### win_firewall::block_local_port and win_firewall::open_local_port
/modules/win_firewall/manifests/open_local_port.pp
Purpose: To explicitly block or open local port.

Required parameters:
* $fw_display_name
* $port
* $reciprocal

Default parameters:
* $remote_ip = any

		win_firewall::open_local_port { "allow_${name}":

			port            => $firewall_port,
			remote_ip       => $firewall_allowed_ips,
			reciprocal      => false,
			fw_display_name => $firewall_name,
		}
		}

##### win_packages::win_exe_pkg

/modules/win_packages/manifests/win_exe_pkg.pp
Purpose: Install exe files:

Required parameters:
* $pkg
* $creates
* $install_options_string (must be a string and not an array)

Default parameters:
* $package=$title

    	win_packages::win_exe_pkg  { 'sublime_text':
			pkg                    => 'SublimeTextBuild3176x64Setup.exe',
			install_options_string => '/VERYSILENT /NORESTART /TASKS=\"contextentry\"',
			creates                => "${facts['custom_win_programfiles']}\\Sublime Text 3\\subl.exe",
		}

*NOTE*: There is no direct way in Puppet in Puppet or with in the way Windows installs exe(s) to managed versions. The current method is to create a custom fact for the version and do a comparison in the manifest.
*NOTE*: For all packages installed by defined type the file must be placed in win_ext_pkg_src which can be find in /data/os/Windows

##### win_packages::win_msi_pkg

/modules/win_packages/manifests/win_msi_pkg.pp

Required parameters:
* $pkg
* $install_options (must be an array and not a string)

Default parameters:
* $package=$title

		win_packages::win_msi_pkg { '7-Zip 18.06 (x64 edition)':
			pkg             => '7z1806-x64.msi',
			install_options => ['/quiet'],
		}

##### win_packages::win_zip_pkg
/modules/win_packages/manifests/win_zip_pkg.pp
Required parameters:
* $pkg
* $destination
* $creates

Default parameters:
* $package=$title

*NOTE*: This requires the installation of 7zip before working


### R10k Modules
In addition to custom modules in the r10k modules directory are modules downloaded from Puppet Forge. As is this directory is static but is built by R10k and reflects what is listed in the Puppetfile at the root of the repo. To update/remove files from here, one most clone the repo locally, update the Puppetfile, run R10k, and push change back to the repo.

##### Current Forge Modules in Use

[counsyl-windows](https://forge.puppet.com/counsyl/windows)

[ncorrare-windowstime](https://forge.puppet.com/ncorrare/windowstime)

[puppet-windows_firewall](https://forge.puppet.com/puppet/windows_firewall)

[puppetlabs-registry](https://forge.puppet.com/puppetlabs/registry)

[puppetlabs-powershell](https://forge.puppet.com/puppetlabs/powershell)

[puppetlabs-acl](https://forge.puppet.com/puppetlabs/acl)

[ipcrm-registry_acl](https://forge.puppet.com/ipcrm/registry_acl)

[puppetlabs-scheduled_task]( https://forge.puppet.com/puppetlabs/scheduled_task)
