# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_taskcluster_cloud::worker_runner (
  String $worker_runner_dir,
  String $worker_runner_exe_path,
  String $worker_runner_exe_source,
  String $worker_runner_yaml_path,
  String $worker_runner_nssm_service_start,
  String $worker_runner_nssm_service_type,
  String $worker_runner_nssm_app_exit,
  String $worker_runner_log,
  String $nssm_exe,
  String $worker_runner_provider,
  String $worker_runner_implementation,
  String $gw_config_file,
) {
  require win_packages::custom_nssm

  file { $worker_runner_dir:
    ensure => directory,
  }
  file { $worker_runner_exe_path:
    source  => $worker_runner_exe_source,
  }

  file { $worker_runner_yaml_path:
    content   => epp('win_taskcluster_cloud/runner.yml.epp'),
  }

  exec { 'convert_runner_yml':
    command     => "(Get-Content ${worker_runner_yaml_path} -Raw).Replace(\"`r`n\",\"`n\") | Set-Content ${worker_runner_yaml_path} -Force",
    subscribe   => File[$worker_runner_yaml_path],
    provider    => powershell,
    refreshonly => true,
  }

  if $facts['custom_win_runner_service'] != 'present' {
    exec { 'install_runner_service':
      command => "${nssm_exe} install worker-runner ${worker_runner_exe_path}",
    }
    exec { 'set_runner_app_dir':
      command => "${nssm_exe} AppDirectory ${worker_runner_dir}",
    }
    exec { 'set_runner_app_params':
      command => "${nssm_exe} AppParameters ${worker_runner_yaml_path}",
    }
    exec { 'set_runner_display_name':
      command => "${nssm_exe} DisplayName \"Worker Runner\"",
    }
    exec { 'set_runner_descritption':
      command => "${nssm_exe} Description \"Interface between workers and Taskcluster services\"",
    }
    exec { 'set_runner_start':
      command => "${nssm_exe} Start ${worker_runner_nssm_service_start}",
    }
    exec { 'set_runner_type':
      command => "${nssm_exe} Type ${worker_runner_nssm_service_type}",
    }
    exec { 'set_runner_appnoconsole':
      command => "${nssm_exe} AppNoConsole 1",
    }
    exec { 'set_runner_appaffinity':
      command => "${nssm_exe} AppAffinity All",
    }
    exec { 'set_runner_appstopmethodskip':
      command => "${nssm_exe} AppStopMethodSkip 0",
    }
    exec { 'set_runner_appexit':
      command => "${nssm_exe} AppExit ${worker_runner_nssm_app_exit}",
    }
    exec { 'set_runner_restart_delay':
      command => "${nssm_exe} AppRestartDelay 0",
    }
    exec { 'set_runner_stdout':
      command => "${nssm_exe} AppStdout ${worker_runner_log}",
    }
    exec { 'set_runner_stderror':
      command => "${nssm_exe} AppStderr ${worker_runner_log}",
    }
    exec { 'set_runner_rotate_file':
      command => "${nssm_exe} AppRotateFiles 1",
    }
    exec { 'set_runner_rotate_online':
      command => "${nssm_exe} AppRotateOnline 1",
    }
    exec { 'set_runner_rotate_seconds':
      command => "${nssm_exe} AppRotateSeconds 3600",
    }
    exec { 'set_runner_rotate_bytes':
      command => "${nssm_exe} AppRotateBytes 0",
    }
  }
}
