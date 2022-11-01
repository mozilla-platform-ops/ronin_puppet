# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_taskcluster::generic_worker (
  String $generic_worker_dir,
  String $desired_gw_version,
  String $current_gw_version,
  String $gw_exe_source,
  String $gw_exe_path,
  String $init_file
) {
  $ed25519private = "${generic_worker_dir}\\ed25519-private.key"

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
  file { $gw_exe_path:
    source  => $gw_exe_source,
  }
  exec { 'generate_ed25519_keypair':
    command => "${gw_exe_path} new-ed25519-keypair --file ${ed25519private}",
    creates => $ed25519private,
  }
  # TODO: Add conditional language to profile based on OS version
  # To pass the correct source file name instead of hard code
  file { "${generic_worker_dir}\\task-user-init.cmd":
    content   => file("win_taskcluster/${init_file}"),
  }
  if $init_file == 'task-user-init-win11.cmd' {
    # C:\generic-worker\task-user-init.ps1
    file { "${generic_worker_dir}\\task-user-init.ps1":
      content   => file("win_taskcluster/task-user-init.ps1"),
    }
  }
}
