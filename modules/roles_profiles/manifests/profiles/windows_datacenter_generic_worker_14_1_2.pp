# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::windows_datacenter_generic_worker_14_1_2 {

    case $::operatingsystem {
        'Windows': {

            $taskcluster_access_token = lookup('taskcluster_access_token')
            $ext_pkg_src_loc          = lookup('win_ext_pkg_src')
            $tc_pkg_source            = "${ext_pkg_src_loc}/taskcluster"
            # Determined in /modules/win_shared/facts.d/facts_win_application_versions.ps1
            $current_gw_version       = $facts['custom_win_genericworker_version']
            $generic_worker_dir       = "${facts['custom_win_systemdrive']}\\generic-worker"
            $generic_worker_exe       = "${generic_worker_dir}\\generic-worker.exe"
            $generic_worker_config    = "${generic_worker_dir}\\gen-worker.config"

            # Defining below  as variables because there may be
            # a need to add logic to determine which source or version is needed
            # dependent on OS or architecture.
            $needed_gw_version         = '14.1.2'
            $needed_tc_proxy_version   = '5.1.0'
            $needed_livelog_version    = '1.1.0'
            # Requires win_packages::nssm
            $nssm_command              = "${facts['custom_win_systemdrive']}\\nssm\\nssm-2.24-103-gdee49fc\\win64\\nssm.exe"

            class { 'win_generic_worker':
                generic_worker_dir             => $generic_worker_dir,
                cache_dir                      => "${facts['custom_win_systemdrive']}\\cache",
                downloads_dir                  => "${facts['custom_win_systemdrive']}\\downloads",
                livelogputport                 => 60022,
                current_gw_version             => $current_gw_version,
                needed_gw_version              => $needed_gw_version,
                generic_worker_config          => $generic_worker_config,
                generic_worker_exe             => $generic_worker_exe,
                generic_worker_install_command =>
                    "${generic_worker_exe} install service --nssm ${nssm_command} --config ${generic_worker_config}",
                run_generic_worker_command     => "${generic_worker_exe} run --config ${generic_worker_config}",
                generic_worker_exe_source      => "${tc_pkg_source}/generic-worker-nativeEngine-windows-amd64-${needed_gw_version}.exe",
                taskcluster_proxy_exe_source   => "${tc_pkg_source}/taskcluster-proxy-windows-amd64-${needed_tc_proxy_version}.exe",
                livelog_exe_source             => "${tc_pkg_source}/livelog-windows-amd64-${needed_livelog_version}.exe",

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
            class{ 'win_generic_worker::hw_config':
                taskcluster_access_token => $taskcluster_access_token,
                worker_type              => $facts['custom_win_gw_workertype'],
                client_id                => "project//releng//generic-worker//${facts['custom_win_gw_workertype']}//production",
                generic_worker_dir       => "${facts['custom_win_systemdrive']}\\\\generic-worker",
                provisioner_id           => 'releng-hardware',
                idle_timeout             => 7200,
            }
        }

        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
