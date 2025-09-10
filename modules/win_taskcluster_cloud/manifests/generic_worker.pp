# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_taskcluster_cloud::generic_worker (
  String $generic_worker_dir,
  String $gw_exe_source,
  String $init_file,
  String $gw_exe_path,
  String $nssm_exe,
  String $gw_app_parameters,
  String $gw_nssm_service_start,
  String $gw_nssm_service_type,
  String $gw_nssm_app_exit,
  String $gw_log_file,
  String $ed25519signingkey,
  String $ed25519signingkey_path,
) {
  require win_packages::custom_nssm

  file { $generic_worker_dir:
    ensure => directory,
  }

  file { $gw_exe_path:
    source  => $gw_exe_source,
  }

  exec { 'generate_ed25519_keypair':
    command => "${gw_exe_path} new-ed25519-keypair --file ${ed25519signingkey}",
    creates => $ed25519signingkey_path,
  }

  file { "${generic_worker_dir}\\task-user-init.cmd":
    content   => file("win_taskcluster_cloud/${init_file}"),
  }

  file { "${generic_worker_dir}\\task-user-init.ps1":
    content   => file('win_taskcluster_cloud/task-user-init.ps1'),
  }

  exec { 'install_gw_service':
    command => "${nssm_exe} install \"Generic Worker\" ${gw_exe_path}",
  }
  exec { 'set_gw_app_dir':
    command => "${nssm_exe} set AppDirectory ${generic_worker_dir}",
  }
  exec { 'set_gw_app_parameters':
    command => "${nssm_exe} set AppParameters ${gw_app_parameters}",
  }
  exec { 'set_gw_display_name':
    command => "${nssm_exe} set DisplayName \"Generic Worker\"",
  }
  exec { 'set_gw_description':
    command => "${nssm_exe} set Description \"A taskcluster worker that runs on all mainstream platforms\"",
  }
  exec { 'set_gw_start':
    command => "${nssm_exe} set Start ${gw_nssm_service_start}",
  }
  exec { 'set_gw_type':
    command => "${nssm_exe} set Type ${gw_nssm_service_type}",
  }
  exec { 'set_gw_appnoconsole':
    command => "${nssm_exe} set AppNoConsole 1",
  }
  exec { 'set_gw_appaffinity':
    command => "${nssm_exe} set AppAffinity All",
  }
  exec { 'set_gw_appstopmethodskip':
    command => "${nssm_exe} set AppStopMethodSkip 0",
  }
  exec { 'set_gw_appexit':
    command => "${nssm_exe} set AppExit ${gw_nssm_app_exit}",
  }
  exec { 'set_gw_restart_delay':
    command => "${nssm_exe} set AppRestartDelay 0",
  }
  exec { 'set_gw_stdout':
    command => "${nssm_exe} set AppStdout ${gw_log_file}",
  }
  exec { 'set_gw_stderror':
    command => "${nssm_exe} set AppStderr ${gw_log_file}",
  }
  exec { 'set_gw_rotate_file':
    command => "${nssm_exe} set AppRotateFiles 1",
  }
}
