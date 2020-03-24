# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::windows_worker_runner {

    case $::operatingsystem {
        'Windows': {

            $nssm_dir              = lookup('windows.dir.nssm')
            $nssm_version          = lookup('win-worker.nssm.version')
            if $facts['os']['architecture'] == 'x86' {
                $arch = 'win32'
            } else {
                $arch = 'win64'
            }
            $nssm_exe              =  "${nssm_dir}\\nssm-${nssm_version}\\${arch}\\nssm.exe"

            $ext_pkg_src_loc       = lookup('windows.taskcluster.relops_s3')

            $generic_worker_dir    = lookup('windows.dir.generic_worker')
            $gw_name               = lookup('win-worker.generic_worker.name')
            $desired_gw_version    = lookup('win-worker.generic_worker.exe_version')
            $gw_exe_path           = "${generic_worker_dir}\\generic-worker.exe"

            $worker_runner_dir     = lookup('windows.dir.worker_runner')
            $desired_rnr_version   = lookup('win-worker.taskcluster.worker_runner.version')
            $runner_log            = "${worker_runner_dir}\\worker-runner-service.log"

            $desired_proxy_version = lookup('win-worker.taskcluster.proxy.version')
            $proxy_name            = lookup('win-worker.taskcluster.proxy.name')

            # Livelog command does not have a version flag
            # Locking the version file name
            $livelog_file          = lookup('win-worker.taskcluster.livelog_exe')

            class { 'win_packages::custom_nssm':
                version  => $nssm_version,
                nssm_exe => $nssm_exe,
                nssm_dir => $nssm_dir,
            }

            class { 'win_taskcluster::generic_worker' :
                generic_worker_dir => $generic_worker_dir,
                desired_gw_version => $desired_gw_version,
                current_gw_version => $facts['custom_win_genericworker_version'],
                gw_exe_source      => "${ext_pkg_src_loc}/${gw_name}-${desired_gw_version}.exe",
                gw_exe_path        => $gw_exe_path,
            }
            class { 'win_taskcluster::worker_runner':
                worker_runner_dir      => $worker_runner_dir,
                desired_runner_version => $desired_rnr_version,
                current_runner_version => $facts['custom_win_runner_version'],
                runner_exe_source      => "${ext_pkg_src_loc}/start-worker-${desired_rnr_version}.exe",
                # Yaml file data
                provider               => lookup('win-worker.taskcluster.worker_runner.provider'),
                implementation         => lookup('win-worker.taskcluster.worker_runner.implementation'),
                # Runner service install data
                gw_exe_path            => $gw_exe_path,
                runner_exe_path        => "${worker_runner_dir}\\start-worker.exe",
                runner_yml             => "${worker_runner_dir}\\runner.yml",
                runner_log             => $runner_log,
                nssm_exe               => $nssm_exe,
            }
            class { 'win_taskcluster::proxy':
                generic_worker_dir    => $generic_worker_dir,
                desired_proxy_version => $desired_proxy_version,
                current_proxy_version => $facts['custom_win_taskcluster_proxy_version'],
                proxy_exe_source      => "${ext_pkg_src_loc}/${proxy_name}-${desired_proxy_version}.exe",
            }
            class { 'win_taskcluster::livelog':
                generic_worker_dir => $generic_worker_dir,
                livelog_exe_source => "${ext_pkg_src_loc}/${livelog_file}",
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
