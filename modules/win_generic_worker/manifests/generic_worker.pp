# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class  win_generic_worker::generic_worker (
  String $cache_dir,
  String $client_id,
  String $current_gw_version,
  String $current_proxy_version,
  String $desired_gw_version,
  String $desired_proxy_version,
  String $downloads_dir,
  String $ed25519signingkey,
  Integer $idle_timeout,
  String $init_file,
  String $init_path,
  String $init_ps,
  String $generic_worker_dir,
  String $gw_config_path,
  String $gw_exe_path,
  String $gw_exe_source,
  #String $gw_install_command,
  String $gw_status,
  String $livelog_exe,
  String $livelog_exe_source,
  String $task_dir,
  String $taskcluster_access_token,
  String $taskcluster_proxy_exe,
  String $taskcluster_proxy_source,
  String $taskcluster_root,
  #String $task_user_init_cmd,
  String $wstaudience,
  String $wstserverurl,
  String $worker_type
) {


    #require win_packages::custom_nssm

    file { $generic_worker_dir:
        ensure => directory,
    }
    file { $cache_dir:
        ensure => directory,
    }
    file { $downloads_dir:
        ensure => directory,
    }

    file { $gw_config_path:
        content   => epp('win_generic_worker/hw-generic-worker.config.epp'),
        show_diff => false,
    }
    file { $livelog_exe:
        source  => $livelog_exe_source,
    }
    file { $taskcluster_proxy_exe:
        source  => $taskcluster_proxy_source,
    }
    if ($current_gw_version != $desired_gw_version) {
            exec { 'purge_old_gw_exe':
            command  => "remove-Item -path ${gw_exe_path}",
            provider => powershell,
        }
    }
    if ($current_proxy_version != $desired_proxy_version) {
        exec { 'purge_old_proxy_exe':
            command  => "Remove-Item -path ${taskcluster_proxy_exe}",
            unless   => "Test-Path ${taskcluster_proxy_exe}",
            provider => powershell,
        }
    }
    file { $gw_exe_path:
        source => $gw_exe_source,
    }
    exec { 'generate_ed25519_keypair':
        command =>
            "${gw_exe_path} new-ed25519-keypair --file ${ed25519signingkey}",
        require => File[$gw_exe_path],
        creates => $ed25519signingkey,
    }
    file { $init_path:
        content   => file("win_generic_worker/${init_file}"),
    }
    file { $init_ps:
        content   => file('win_generic_worker/task-user-init.ps1'),
    }
}
