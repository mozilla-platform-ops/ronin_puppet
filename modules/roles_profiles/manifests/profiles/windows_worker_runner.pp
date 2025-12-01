# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# @summary Installs and configures Taskcluster worker components on Windows
#
# @param build_from_source
#   If set to 'true', builds generic-worker from source instead of downloading a release binary
#
# @param taskcluster_repo
#   The git repository URL for the Taskcluster project (used when building from source)
#
# @param taskcluster_ref
#   The git ref (branch, tag, or commit) to checkout when building from source
#
class roles_profiles::profiles::windows_worker_runner (
  Optional[String] $build_from_source = undef,
  String $taskcluster_repo = 'https://github.com/taskcluster/taskcluster',
  Optional[String] $taskcluster_ref = undef,
) {
  case $facts['os']['name'] {
    'Windows': {
      $nssm_dir              = lookup('windows.dir.nssm')
      $nssm_version          = lookup('windows.nssm.version')
      $nssm_exe              =  "${nssm_dir}\\nssm-${nssm_version}\\win64\\nssm.exe"

      case $facts['custom_win_location'] {
        'datacenter': {
          $ext_pkg_src_loc = lookup('windows.taskcluster.relops_s3')
          $provider = 'standalone'
        }
        default: {
          #$ext_pkg_src_loc = lookup('windows.taskcluster.relops_az')
          $ext_pkg_src_loc = "${lookup('windows.taskcluster.download_url')}/v"
          #$ext_pkg_src_loc = "https://github.com/taskcluster/taskcluster/releases/download/v93.1.4/generic-worker-multiuser-windows-arm64"
          $provider = lookup('windows.taskcluster.worker_runner.provider')
        }
      }

      $taskcluster_version    =
        lookup(['win-worker.variant.taskcluster.version', 'windows.taskcluster.version'])

      case $facts['custom_win_os_arch'] {
        'aarch64': {
          $gw_name               = lookup('windows.taskcluster.generic-worker.name.arm64')
          $proxy_name            = lookup('windows.taskcluster.proxy.name.arm64')
          $livelog_name          = lookup('windows.taskcluster.livelog.name.arm64')
          $runner_name           = lookup('windows.taskcluster.worker_runner.name.arm64')
        }
        default: {
          $gw_name               = lookup('windows.taskcluster.generic-worker.name.amd64')
          $proxy_name            = lookup('windows.taskcluster.proxy.name.amd64')
          $livelog_name          = lookup('windows.taskcluster.livelog.name.amd64')
          $runner_name           = lookup('windows.taskcluster.worker_runner.name.amd64')
        }
      }

      $generic_worker_dir    = lookup('windows.dir.generic_worker')
      #$gw_name               = lookup('windows.taskcluster.generic-worker.name.amd64')
      $desired_gw_version    = $taskcluster_version
      $gw_exe_path           = "${generic_worker_dir}\\generic-worker.exe"

      $desired_proxy_version = $taskcluster_version
      #$proxy_name            = lookup('windows.taskcluster.proxy.name.amd64')

      # Livelog command does not have a version flag
      # Locking the version file name
      #$livelog_name          = lookup('windows.taskcluster.livelog.name.amd64')
      $livelog_version       = $taskcluster_version

      $worker_runner_dir     = lookup('windows.dir.worker_runner')
      $desired_rnr_version   = $taskcluster_version
      $runner_log            = "${worker_runner_dir}\\worker-runner-service.log"
      $implementation        = lookup('windows.taskcluster.worker_runner.implementation')
      $config_file            = "${facts['custom_win_systemdrive']}\\generic-worker\\generic-worker.config"

      case $facts['custom_win_os_version'] {
        'win_10_2009': {
          $init = 'task-user-init-win10-64-2009.cmd'
        }
        'win_11_2009': {
          $init = 'task-user-init-win11.cmd'
        }
        'win_2012': {
          $init = 'task-user-init-win2012.cmd'
        }
        'win_10_2004': {
          $init = 'task-user-init-win10.cmd'
        }
        'win_2022_2009': {
          $init = 'task-user-init-win2012.cmd'
        }
        default: {
          $init = undef
        }
      }

      case $provider {
        'standalone': {
          $access_token          = lookup('taskcluster_access_token')
          $cache_dir             = "${facts['custom_win_systemdrive']}\\\\cache"
          $client_id             = lookup('win-worker.generic_worker.client_id')
          $downloads_dir         = "${facts['custom_win_systemdrive']}\\\\downloads"
          $ed25519signingkey     = "${facts['custom_win_systemdrive']}\\\\generic-worker\\\\ed25519-private.key"
          $idle_timeout          =  lookup('windows.taskcluster.hardware_idle_timeout')
          $livelog_exe           = "${facts['custom_win_systemdrive']}\\\\generic-worker\\\\livelog.exe"
          $location              = $facts['custom_win_location']
          $provisioner           = 'releng-hardware'
          $root_url              = lookup('windows.taskcluster.root_url')
          $task_dir              = "${facts['custom_win_systemdrive']}\\\\"
          $task_user_init_cmd    = "${generic_worker_dir}\\\\task-user-init.cmd"
          $taskcluster_proxy_exe = "${facts['custom_win_systemdrive']}\\\\generic-worker\\\\taskcluster-proxy.exe"
          $taskcluster_root_url  = lookup('windows.taskcluster.root_url')
          $worker_id             = $facts['networking']['hostname']
          $worker_group          = 'mdc1'
          $worker_pool_id        = $facts['custom_win_worker_pool_id']
          $wstaudience           = lookup('windows.taskcluster.wstaudience')
          $wstserverurl          = lookup('windows.taskcluster.wstserverurl')
        }
        default: {
          $access_token          = undef
          $cache_dir             = undef
          $client_id             = undef
          $downloads_dir         = undef
          $ed25519signingkey     = undef
          $idle_timeout          = undef
          $livelog_exe           = undef
          $location              = undef
          $provisioner           = undef
          $root_url              = undef
          $task_dir              = undef
          $task_user_init_cmd    = undef
          $taskcluster_proxy_exe = undef
          $taskcluster_root_url  = undef
          $worker_id             = undef
          $worker_group          = undef
          $worker_pool_id        = undef
          $wstaudience           = undef
          $wstserverurl          = undef
        }
      }

      class { 'win_packages::custom_nssm':
        version  => $nssm_version,
        nssm_exe => $nssm_exe,
        nssm_dir => $nssm_dir,
      }

      class { 'win_taskcluster::generic_worker' :
        generic_worker_dir => $generic_worker_dir,
        desired_gw_version => $desired_gw_version,
        current_gw_version => $facts['custom_win_genericworker_version'],
        gw_exe_source      => "${ext_pkg_src_loc}${desired_gw_version}/${gw_name}",
        init_file          => $init,
        gw_exe_path        => $gw_exe_path,
        build_from_source  => $build_from_source,
        taskcluster_repo   => $taskcluster_repo,
        taskcluster_ref    => $taskcluster_ref,
      }
      class { 'win_taskcluster::proxy':
        generic_worker_dir    => $generic_worker_dir,
        desired_proxy_version => $desired_proxy_version,
        current_proxy_version => $facts['custom_win_taskcluster_proxy_version'],
        proxy_exe_source      => "${ext_pkg_src_loc}${desired_proxy_version}/${proxy_name}",
      }
      class { 'win_taskcluster::livelog':
        generic_worker_dir => $generic_worker_dir,
        livelog_exe_source => "${ext_pkg_src_loc}${livelog_version}/${livelog_name}",
      }
      class { 'win_taskcluster::worker_runner':
        # Runner EXE
        worker_runner_dir      => $worker_runner_dir,
        desired_runner_version => $desired_rnr_version,
        current_runner_version => $facts['custom_win_runner_version'],
        runner_exe_source      => "${ext_pkg_src_loc}${desired_rnr_version}/${runner_name}",
        runner_exe_path        => "${worker_runner_dir}\\start-worker.exe",
        runner_yml             => "${worker_runner_dir}\\runner.yml",
        # Runner service install
        gw_exe_path            => $gw_exe_path,
        runner_log             => $runner_log,
        nssm_exe               => $nssm_exe,
        # Runner yaml file
        provider               => $provider,
        implementation         => $implementation,
        # GW config
        access_token           => $access_token,
        cache_dir              => $cache_dir,
        client_id              => $client_id,
        config_file            => $config_file,
        downloads_dir          => $downloads_dir,
        ed25519signingkey      => $ed25519signingkey,
        idle_timeout           => $idle_timeout,
        livelog_exe            => $livelog_exe,
        location               => $location,
        provisioner            => $provisioner,
        root_url               => $root_url,
        task_dir               => $task_dir,
        task_user_init_cmd     => $task_user_init_cmd,
        taskcluster_proxy_exe  => $taskcluster_proxy_exe,
        taskcluster_root_url   => $taskcluster_root_url,
        worker_id              => $worker_id,
        worker_group           => $worker_group,
        worker_pool_id         => $worker_pool_id,
        wstaudience            => $wstaudience,
        wstserverurl           => $wstserverurl,
      }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
