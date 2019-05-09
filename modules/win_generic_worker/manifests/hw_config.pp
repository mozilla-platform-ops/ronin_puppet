# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_generic_worker::hw_config(
    String $taskcluster_access_token,
    String $worker_type,
    String $client_id,
    String $generic_worker_dir,
    String $provisioner_id,
    Integer $idle_timeout
) {

    require win_generic_worker::directories

    # Paths in the  config file need to have \\ hence the \\\\ below
    $cache_dir             = "${facts['custom_win_systemdrive']}\\\\cache"
    $downloads_dir         = "${facts['custom_win_systemdrive']}\\\\downloads"
    $ed25519signingkey     = "${generic_worker_dir}\\\\ed25519-private.key"
    $livelog_exe           = "${generic_worker_dir}\\\\livelog.exe"
    $openpgpsigningkey     = "${generic_worker_dir}\\\\openpgp-private.key"
    $task_user_init_cmd    = "${generic_worker_dir}\\\\task-user-init.cmd"
    $taskcluster_proxy_exe = "${generic_worker_dir}\\\\taskcluster-proxy.exe"
    $task_dir              = "${facts['custom_win_systemdrive']}\\\\Users"


    file { $win_generic_worker::generic_worker_config:
        content   => epp('win_generic_worker/hw-generic-worker.config.epp'),
        show_diff => false,
    }
}
