# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class  win_generic_worker::generic_worker (
  String $cache_dir,
  String $client_id,
  String $current_gw_version,
  String $desired_gw_version,
  String $downloads_dir,
  String $ed25519signingkey,
  String $idle_timeout,
  String $init_file,
  String $generic_worker_dir,
  String $gw_exe_path,
  String $gw_exe_source,
  String $livelog_exe,
  String $task_dir,
  String $taskcluster_access_token,
  String $taskcluster_proxy_exe,
  String $taskcluster_root,
  String $task_user_init_cmd,
  String $wstaudience,
  String $wstserverurl,
  String $worker_type
) {


    file { $generic_worker_dir:
        ensure => directory,
    }
    file { $cache_dir:
        ensure => directory,
    }
    file { $downloads_dir:
        ensure => directory,
    }

    file { $win_generic_worker::generic_worker_config:
        content   => epp('win_generic_worker/hw-generic-worker.config.epp'),
        show_diff => false,
    }
}
