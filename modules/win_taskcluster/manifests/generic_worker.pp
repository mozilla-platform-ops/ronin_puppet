# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_taskcluster::generic_worker (
  String $generic_worker_dir,
  String $gw_exe_source,
  String $gw_exe_path,
  String $init_file
) {
  $ed25519private = "${generic_worker_dir}\\ed25519-private.key"

  file { $generic_worker_dir:
    ensure => directory,
  }
  acl { $generic_worker_dir:
    owner                      => 'S-1-5-18',
    inherit_parent_permissions => false,
    purge                      => true,
    permissions                => [
      { identity => 'S-1-5-18', rights => ['full'] },
      { identity => 'S-1-5-32-544', rights => ['full'] },
      { identity => 'S-1-5-32-545', rights => ['read', 'execute'] },
    ],
    require                    => File[$generic_worker_dir],
  }
  file { $gw_exe_path:
    source  => $gw_exe_source,
    require => Acl[$generic_worker_dir],
  }
  exec { 'generate_ed25519_keypair':
    command => "${gw_exe_path} new-ed25519-keypair --file ${ed25519private}",
    creates => $ed25519private,
    require => File[$gw_exe_path],
  }
  file { "${generic_worker_dir}\\task-user-init.cmd":
    content => file("win_taskcluster/${init_file}"),
    require => Acl[$generic_worker_dir],
  }
  # C:\generic-worker\task-user-init.ps1
  file { "${generic_worker_dir}\\task-user-init.ps1":
    content => file('win_taskcluster/task-user-init.ps1'),
    require => Acl[$generic_worker_dir],
  }
}
