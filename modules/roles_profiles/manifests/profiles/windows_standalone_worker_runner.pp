# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::windows_standalone_worker_runner {

    case $::operatingsystem {
        'Windows': {

            $ext_pkg_src_loc       = lookup('windows.taskcluster.relops_s3')

            $generic_worker_dir    = lookup('windows.dir.generic_worker')
            $gw_name               = lookup('win-worker.generic_worker.name')
            $desired_gw_version    = lookup('win-worker.generic_worker.exe_version')

            $worker_runner_dir     = lookup('windows.dir.worker_runner')
            $desired_rnr_version   = lookup('win-worker.taskcluster.worker_runner_version')

            $desired_proxy_version = lookup('win-worker.taskcluster.proxy.version')
            $proxy_name            = lookup('win-worker.taskcluster.proxy.name')

            class { 'win_taskcluster::generic_worker' :
                generic_worker_dir => $generic_worker_dir,
                desired_gw_version => $desired_gw_version,
                current_gw_version => $facts['custom_win_genericworker_version'],
                gw_exe_source      => "${ext_pkg_src_loc}/${gw_name}-${desired_gw_version}.exe",
            }
            class { 'win_taskcluster::worker_runner':
                worker_runner_dir      => $worker_runner_dir,
                desired_runner_version => $desired_rnr_version,
                current_runner_version => $facts['custom_win_runner_version'],
                runner_exe_source      => "${ext_pkg_src_loc}/start-worker-${desired_rnr_version}.exe",
            }
            class { 'win_taskcluster::proxy':
                generic_worker_dir    => $generic_worker_dir,
                desired_proxy_version => $desired_proxy_version,
                current_proxy_version => $facts['custom_win_taskcluster_proxy_version'],
                proxy_exe_source      => "${ext_pkg_src_loc}/${proxy_name}-${desired_proxy_version}.exe",
            }

        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
