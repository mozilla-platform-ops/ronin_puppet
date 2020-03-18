# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_taskcluster::worker_runner (
    String $worker_runner_dir,
    String $desired_runner_version,
    String $current_runner_version,
    String $runner_exe_source,
    String $provider,
    String $runner_exe_path,
    String $runner_yml,
    String $runner_log,
    String $nssm_exe,
    String $runner_service_start = 'SERVICE_DEMAND_START',
    String $runner_service_type = 'SERVICE_WIN32_OWN_PROCESS',
    String $runner_app_exit = 'Default Exit',
    $root_url = undef,
    $client_id = undef,
    $access_token = undef,
    $worker_pool_id = undef,
    $worker_group = undef,
    $worker_id = undef,
    $gw_exe_path = undef,
    $config_file = undef
) {

    require win_packages::custom_nssm

    $nssm_set = "${nssm_exe} set worker-runner"

    if ($current_runner_version != $desired_runner_version) {
        exec { 'purge_old_gw_exe':
            command  => "remove-Item –path ${runner_exe_path}",
            unless   => "Test-Path ${runner_exe_path}",
            provider => powershell,
        }
    }
    file { $worker_runner_dir:
        ensure => directory,
    }
    file { $runner_exe_path:
        source  => $runner_exe_source,
    }
    if $provider == 'standalone' {
        file { $runner_yml:
        #"${worker_runner_dir}\\runner.yml":
            content   => epp('win_taskcluster/standalone_runner.yml.epp'),
        }
        # Worker-runner/Go need the config file to have UNIX-style line endings
        # As is the file generated will have CRLF endings
        exec { 'convert_runner_yml':
            command => "(Get-Content ${runner_yml}  -Raw).Replace(\"`r`n\",\"`n\") | Set-Content ${runner_yml} -Force",
            require => File[$runner_yml],
            #refreshonly => true,
        }
    }
    else {
        warning("Unable to provide config file for ${provider} provider")
    }
    if $facts['custom_win_runner_service'] != 'present' {
        exec { 'install_runner_service':
            command => "${nssm_exe} install worker-runner ${runner_exe_path}",
        }
        exec { 'set_runner_app_dir':
            command => "${nssm_set} AppDirectory ${worker_runner_dir}",
        }
        exec { 'set_runner_app_params':
            command => "${nssm_set} AppParameters ${runner_yml}",
        }
        exec {'set_runner_display_name':
            command => "${nssm_set} DisplayName \"Worker Runner\"",
        }
        exec {'set_runner_descritption':
            command => "${nssm_set} Description \"Interface between workers and Taskcluster services\"",
        }
        exec {'set_runner_start':
            command => "${nssm_set} Start ${runner_service_start}",
        }
        exec {'set_runner_type':
            command => "${nssm_set} Type ${runner_service_type}",
        }
        exec {'set_runner_appnoconsole':
            command => "${nssm_set} AppNoConsole 1",
        }
        exec {'set_runner_appaffinity':
            command => "${nssm_set} AppAffinity All",
        }
        exec {'set_runner_appstopmethodskip':
            command => "${nssm_set} AppStopMethodSkip 0",
        }
        exec {'set_runner_appexit':
            command => "${nssm_set} AppExit ${runner_app_exit}",
        }
        exec {'set_runner_restart_delay':
            command => "${nssm_set} AppRestartDelay 0",
        }
        exec {'set_runner_stdout':
            command => "${nssm_set} AppStdout ${runner_log}",
        }
        exec {'set_runner_stderror':
            command => "${nssm_set} AppStderr ${runner_log}",
        }
        exec {'set_runner_rotate_file':
            command => "${nssm_set} AppRotateFiles 1",
        }
        exec {'set_runner_rotate_online':
            command => "${nssm_set} AppRotateOnline 1",
        }
        exec {'set_runner_rotate_seconds':
            command => "${nssm_set} AppRotateSeconds 3600",
        }
        exec {'set_runner_rotate_bytes':
            command => "${nssm_set} AppRotateBytes 0",
        }
    }
}
