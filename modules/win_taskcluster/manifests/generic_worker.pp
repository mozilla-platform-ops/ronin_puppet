# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_taskcluster::generic_worker (
  String $generic_worker_dir,
  String $gw_exe_source,
  String $gw_exe_path,
  String $init_file,
  Optional[Struct[{
    'repository' => Pattern[/\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\z/],
    'revision'   => Pattern[/\A[0-9a-f]{40}\z/],
    'go_version' => Pattern[/\A[0-9]+\.[0-9]+\.[0-9]+\z/],
  }]] $source_build = undef,
) {
  $ed25519private = "${generic_worker_dir}\\ed25519-private.key"

  file { $generic_worker_dir:
    ensure => directory,
  }
  if $source_build {
    # Test branch only. The stamp prevents Puppet from restoring a consumed seed.
    file { 'C:\cache-seeds':
      ensure => directory,
    }
    acl { 'C:\cache-seeds':
      owner                      => 'SYSTEM',
      purge                      => true,
      inherit_parent_permissions => false,
      permissions                => [
        { 'identity' => 'SYSTEM', 'rights' => ['full'] },
        { 'identity' => 'Administrators', 'rights' => ['full'] },
      ],
      require                    => File['C:\cache-seeds'],
    }
    exec { 'create_preloaded_cache_smoke_seed':
      command  => file('win_taskcluster/create-cache-smoke-seed.ps1'),
      creates  => 'C:\cache-seeds\relops-8809-smoke-20260917.created',
      provider => powershell,
      require  => Acl['C:\cache-seeds'],
    }
    $architecture = $facts['custom_win_os_arch'] ? {
      'aarch64' => 'arm64',
      default   => 'amd64',
    }
    $build_script = "${generic_worker_dir}\\build-generic-worker.ps1"
    file { $build_script:
      source => 'puppet:///modules/win_taskcluster/build-generic-worker.ps1',
    }
    $build_command = "& '${build_script}' -Repository '${source_build['repository']}' -Revision '${source_build['revision']}' -GoVersion '${source_build['go_version']}' -Architecture '${architecture}' -Destination '${gw_exe_path}'"
    exec { 'build_generic_worker':
      command  => $build_command,
      unless   => "${build_command} -Check",
      provider => powershell,
      timeout  => 1800,
      require  => File[$build_script],
    }
    $gw_exe_dependency = Exec['build_generic_worker']
  } else {
    file { $gw_exe_path:
      source => $gw_exe_source,
    }
    $gw_exe_dependency = File[$gw_exe_path]
  }
  exec { 'generate_ed25519_keypair':
    command => "${gw_exe_path} new-ed25519-keypair --file ${ed25519private}",
    creates => $ed25519private,
    require => $gw_exe_dependency,
  }
  file { "${generic_worker_dir}\\task-user-init.cmd":
    content => file("win_taskcluster/${init_file}"),
  }
  # C:\generic-worker\task-user-init.ps1
  file { "${generic_worker_dir}\\task-user-init.ps1":
    content => file('win_taskcluster/task-user-init.ps1'),
  }
}
