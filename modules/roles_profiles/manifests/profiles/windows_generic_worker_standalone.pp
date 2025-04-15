# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::windows_generic_worker_standalone {

    case $facts['os']['name'] {
        'Windows': {

            $nssm_dir     = lookup('windows.dir.nssm')
            $nssm_version = lookup('win-worker.nssm.version')
            $arch         = 'win64'
            $nssm_exe     = "${nssm_dir}\\nssm-${nssm_version}\\${arch}\\nssm.exe"
            $nssm_command = "${facts['custom_win_systemdrive']}\\nssm\\nssm-2.24\\win64\\nssm.exe"

            $ext_pkg_src_loc = lookup('windows.taskcluster.relops_az')

            $generic_worker_dir    = lookup('windows.dir.generic_worker')
            $gw_name               = lookup('win-worker.generic_worker.name')
            $gw_exe_path           = "${generic_worker_dir}\\generic-worker.exe"
            $desired_gw_version    = lookup('win-worker.generic_worker.version')
            $worker_pool_id        = $facts['custom_win_worker_pool_id']
            $gw_config_path        = "${generic_worker_dir}\\generic-worker.config"


            $desired_proxy_version = lookup('win-worker.taskcluster.proxy.version')
            $proxy_name            = lookup('win-worker.taskcluster.proxy.name')

            $livelog_name          = lookup('win-worker.taskcluster.livelog.name')
            $livelog_version       = lookup('win-worker.taskcluster.livelog.version')

            $config_file            = "${facts['custom_win_systemdrive']}\\generic-worker\\generic-worker.config"

            case $facts['custom_win_os_version'] {
                'win_10_2009': {
                    $init = 'task-user-init-win10-64-2009.cmd'
                }
                'win_11_2009': {
                    $init = 'task-user-init-win11.cmd'
                }
                default: {
                    $init = undef
                }
            }

            class { 'win_packages::custom_nssm':
                version  => $nssm_version,
                nssm_exe => $nssm_exe,
                nssm_dir => $nssm_dir,
            }

            class { 'win_generic_worker::generic_worker':
                cache_dir                => "${facts['custom_win_systemdrive']}\\\\cache",
                client_id                => lookup('win-worker.generic_worker.client_id'),
                current_gw_version       => $facts['custom_win_genericworker_version'],
                current_proxy_version    => $facts['custom_win_taskcluster_proxy_version'],
                desired_gw_version       => $desired_gw_version,
                desired_proxy_version    => lookup('win-worker.taskcluster.proxy.version'),
                downloads_dir            => "${facts['custom_win_systemdrive']}\\\\downloads",
                ed25519signingkey        => "${facts['custom_win_systemdrive']}\\\\generic-worker\\\\ed25519-private.key",
                idle_timeout             => lookup('win-worker.generic_worker.idle_timeout'),
                init_file                => "${facts['custom_win_systemdrive']}\\\\generic-worker\\\\${init}",
                generic_worker_dir       => $generic_worker_dir,
                gw_config_path           => $gw_config_path,
                gw_exe_path              => $gw_exe_path,
                gw_exe_source            => "${ext_pkg_src_loc}/${desired_gw_version}/${gw_name}",
                gw_install_command       =>
                    "${gw_exe_path} install service --nssm ${nssm_command} --config ${gw_config_path}",
                gw_status                => $facts['custom_win_genericworker_service'],
                livelog_exe              => "${facts['custom_win_systemdrive']}\\\\generic-worker\\\\livelog.exe",
                livelog_exe_source       => "${ext_pkg_src_loc}/${livelog_version}/${livelog_name}",
                task_dir                 => "${facts['custom_win_systemdrive']}\\\\",
                taskcluster_access_token => lookup('taskcluster_access_token'),
                taskcluster_proxy_exe    => "${facts['custom_win_systemdrive']}\\\\generic-worker\\\\taskcluster-proxy.exe",
                taskcluster_proxy_source => "${ext_pkg_src_loc}/${desired_proxy_version}/${proxy_name}",
                taskcluster_root         => lookup('windows.taskcluster.root_url'),
                #task_user_init_cmd      => $init,
                worker_type              => $worker_pool_id,
                wstaudience              => lookup('windows.taskcluster.wstaudience'),
                wstserverurl             => lookup('windows.taskcluster.wstserverurl'),
            }
        }
        default: {
            fail("${$facts['os']['name']} not supported")
        }
    }
}
