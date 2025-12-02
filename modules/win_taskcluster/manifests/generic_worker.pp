# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# @summary Installs and configures generic-worker for Taskcluster
#
# @param generic_worker_dir
#   The directory where generic-worker will be installed
#
# @param desired_gw_version
#   The desired version of generic-worker to install
#
# @param current_gw_version
#   The currently installed version of generic-worker
#
# @param gw_exe_source
#   The source URL for downloading the generic-worker binary
#
# @param gw_exe_path
#   The full path to the generic-worker executable
#
# @param init_file
#   The task-user-init file to use
#
# @param build_from_source
#   If set to 'true', builds generic-worker from source instead of downloading a release binary
#
# @param taskcluster_repo
#   The git repository URL for the Taskcluster project (used when building from source)
#
# @param taskcluster_ref
#   The git ref (branch, tag, or commit) to checkout when building from source
#
class win_taskcluster::generic_worker (
  String $generic_worker_dir,
  String $desired_gw_version,
  String $current_gw_version,
  String $gw_exe_source,
  String $gw_exe_path,
  String $init_file,
  Optional[String] $build_from_source = undef,
  String $taskcluster_repo = 'https://github.com/taskcluster/taskcluster',
  Optional[String] $taskcluster_ref = undef,
) {
  $ed25519private = "${generic_worker_dir}\\ed25519-private.key"
  $build_dir = "${facts['custom_win_systemdrive']}\\taskcluster-build"

  if ($current_gw_version != $desired_gw_version) {
    exec { 'purge_old_nonservice_gw_exe':
      command  => "Remove-Item -path ${gw_exe_path}",
      unless   => "Test-Path ${gw_exe_path}",
      provider => powershell,
    }
  }

  file { $generic_worker_dir:
    ensure => directory,
  }

  if $build_from_source == 'true' {
    # Build generic-worker from source
    $ref_to_checkout = $taskcluster_ref ? {
      undef   => 'main',
      default => $taskcluster_ref,
    }

    $scripts_dir = "${generic_worker_dir}\\scripts"

    # Ensure chocolatey is available
    include chocolatey

    # Install Go via chocolatey
    package { 'golang':
      ensure   => latest,
      provider => chocolatey,
      require  => Class['chocolatey'],
    }

    # Create scripts directory
    file { $scripts_dir:
      ensure => directory,
    }

    # Deploy PowerShell scripts
    file { "${scripts_dir}\\clone-taskcluster-repo.ps1":
      source => 'puppet:///modules/win_taskcluster/clone-taskcluster-repo.ps1',
    }

    file { "${scripts_dir}\\checkout-taskcluster-ref.ps1":
      source => 'puppet:///modules/win_taskcluster/checkout-taskcluster-ref.ps1',
    }

    file { "${scripts_dir}\\build-generic-worker.ps1":
      source => 'puppet:///modules/win_taskcluster/build-generic-worker.ps1',
    }

    exec { 'clone_taskcluster_repo':
      command  => "${scripts_dir}\\clone-taskcluster-repo.ps1 -RepoUrl '${taskcluster_repo}' -BuildDir '${build_dir}'",
      provider => powershell,
      require  => File["${scripts_dir}\\clone-taskcluster-repo.ps1"],
      creates  => $build_dir,
    }

    exec { 'checkout_taskcluster_ref':
      command  => "${scripts_dir}\\checkout-taskcluster-ref.ps1 -BuildDir '${build_dir}' -GitRef '${ref_to_checkout}'",
      provider => powershell,
      require  => [Exec['clone_taskcluster_repo'], File["${scripts_dir}\\checkout-taskcluster-ref.ps1"]],
      unless   => "Set-Location '${build_dir}'; if ((git rev-parse --abbrev-ref HEAD) -eq '${ref_to_checkout}') { exit 0 } else { exit 1 }",
    }

    exec { 'build_generic_worker':
      command  => "${scripts_dir}\\build-generic-worker.ps1 -BuildDir '${build_dir}' -OutputPath '${gw_exe_path}'",
      provider => powershell,
      require  => [
        File[$generic_worker_dir],
        Exec['checkout_taskcluster_ref'],
        Package['golang'],
        File["${scripts_dir}\\build-generic-worker.ps1"],
      ],
      creates  => $gw_exe_path,
    }
  } else {
    # Download generic-worker binary from release
    file { $gw_exe_path:
      source => $gw_exe_source,
    }
  }
  exec { 'generate_ed25519_keypair':
    command => "${gw_exe_path} new-ed25519-keypair --file ${ed25519private}",
    creates => $ed25519private,
  }
  file { "${generic_worker_dir}\\task-user-init.cmd":
    content => file("win_taskcluster/${init_file}"),
  }
  # C:\generic-worker\task-user-init.ps1
  file { "${generic_worker_dir}\\task-user-init.ps1":
    content => file('win_taskcluster/task-user-init.ps1'),
  }
}
