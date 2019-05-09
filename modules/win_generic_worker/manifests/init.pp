# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_generic_worker (
    String $generic_worker_dir,
    String $cache_dir,
    String $downloads_dir,
    Integer $liveloggetport,
    Integer $livelogputport,
    String $livelog_exe_source,
    String $taskcluster_proxy_exe_source,
    String $generic_worker_exe_source,
    String $generic_worker_exe,
    String $current_gw_version,
    String $needed_gw_version,
    STring $generic_worker_config,
    String $generic_worker_install_command,
    String $run_generic_worker_command
) {
    $openpgpsigningkey         = "${generic_worker_dir}\\openpgp-private.key"
    $ed25519signingkey         = "${generic_worker_dir}\\ed25519-private.key"
    $livelog_crt               = "${generic_worker_dir}\\livelog.crt"
    $livelog_exe               = "${generic_worker_dir}\\livelog.exe"
    $livelog_key               = "${generic_worker_dir}\\livelog.key"
    $task_user_init_cmd        = "${generic_worker_dir}\\task-user-init.cmd"
    $disable_desktop_interrupt = "${generic_worker_dir}\\disable-desktop-interrupt.reg"
    $set_default_printer       = "${generic_worker_dir}\\set_default_printer.ps1"
    $taskcluster_proxy_exe     = "${generic_worker_dir}\\taskcluster-proxy.exe"
    $run_generic_worker_bat    = "${generic_worker_dir}\\run-generic-worker.bat"

    if $::operatingsystem == 'Windows' {
        include win_generic_worker::directories
        include win_generic_worker::install
        include win_generic_worker::livelog
        include win_generic_worker::taskcluster_proxy
        include win_generic_worker::scripts

    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1520947
