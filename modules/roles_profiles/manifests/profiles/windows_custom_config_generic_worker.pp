# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::windows_custom_config_generic_worker {

    case $::operatingsystem {
        'Windows': {

            # Installation data
            $gw_exe_version           = lookup('win-worker.generic_worker.exe_version')
            $tc_proxy_version         = lookup('win-worker.generic_worker.tc_proxy_version')
            $livelog_version          = lookup('win-worker.generic_worker.livelog_version')
            $livelogputport           = lookup('win-worker.generic_worker.live_log_put_port')
            $ext_pkg_src_loc          = lookup('win_s3.ext_pkg_src')
            $generic_worker_dir       = "${facts['custom_win_systemdrive']}\\generic-worker"
            $generic_worker_exe       = "${generic_worker_dir}\\generic-worker.exe"
            $generic_worker_config    = "${generic_worker_dir}\\generic-worker.config"
            # Requires win_packages::nssm
            $nssm_command             = "${facts['custom_win_systemdrive']}\\nssm\\nssm-2.24-103-gdee49fc\\win64\\nssm.exe"
            $gw_service_status        = $facts['custom_win_genericworker_service']
            $current_gw_version       = $facts['custom_win_genericworker_version']
            $tc_pkg_source            = "${ext_pkg_src_loc}/taskcluster"

            # Configuration data
            # From secrets file
            $taskcluster_access_token = lookup('taskcluster_access_token')
            # From Hiera
            $taskcluster_root         = lookup('windows.taskcluster.root_url')
            $wstaudience              = lookup('windows.taskcluster.wstaudience')
            $wstserverurl             = lookup('windows.taskcluster.wstserverurl')
            $idle_timeout             = lookup('win-worker.generic_worker.idle_timeout')
            $client_id                = lookup('win-worker.generic_worker.client_id')
            $provisioner_id           = lookup('win-worker.generic_worker.provisioner_id')
            $worker_type              = $facts['custom_win_gw_workertype']

            class { 'win_generic_worker':
                livelogputport                 => $livelogputport,
                gw_service_status              => $gw_service_status,
                current_gw_version             => $current_gw_version,
                needed_gw_version              => $gw_exe_version,
                generic_worker_config          => $generic_worker_config,
                generic_worker_exe             => $generic_worker_exe,
                generic_worker_exe_source      => "${tc_pkg_source}/generic-worker-multiuser-windows-amd64-${gw_exe_version}.exe",
                taskcluster_proxy_exe_source   => "${tc_pkg_source}/taskcluster-proxy-windows-amd64-${tc_proxy_version}.exe",
                livelog_exe_source             => "${tc_pkg_source}/livelog-windows-amd64-${livelog_version}.exe",
                generic_worker_install_command =>
                    "${generic_worker_exe} install service --nssm ${nssm_command} --config ${generic_worker_config}",

            }
            # Orignal sources for the above exe_soruce(s)
            # https://github.com/taskcluster/generic-worker/releases/download/v${needed_gw_version}/generic-worker-windows-amd64.exe
            # https://github.com/taskcluster/taskcluster-proxy/releases/download/v${needed_tc_proxy_version}/taskcluster-proxy-windows-amd64.exe
            # https://github.com/taskcluster/livelog/releases/download/v${needed_livelog_version}/livelog-windows-amd64.exe
            # These can not be pulled directly from the original location becuase puppet does not handle the
            # redirect well.
            # The exe are being are renamed to reflect the version number and and placed in the above mentioned location
            # that can be found in /data/os/Windows.yaml

            # Passing needed parameters directly to the class that is not already available to the module
            # These are specifically needed for the config file which Puppet only manages for hardware
            # Cloud instances will receive the config file during provisioning
            # Paths in the  config file need to have \\ hence the \\\\ below
            class{ 'win_generic_worker::custom_config':
                generic_worker_dir       => generic_worker_dir,
                taskcluster_access_token => $taskcluster_access_token,
                taskcluster_root         => $taskcluster_root,
                wstaudience              => $wstaudience,
                wstserverurl             => $wstserverurl,
                worker_type              => $worker_type,
                client_id                => client_id,
                provisioner_id           => $provisioner_id,
                idle_timeout             => $idle_timeout,
            }
            # On static workers there are often several open profile registries
            # left after tasks are complete. This will clean up those reg values.
            include win_scheduled_tasks::clean_profilelist
        }

        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
