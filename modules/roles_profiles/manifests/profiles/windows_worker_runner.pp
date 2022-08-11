# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::windows_worker_runner {
  case $facts['os']['name'] {
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
      $desired_gw_version    = lookup('win-worker.generic_worker.version')
      $gw_exe_path           = "${generic_worker_dir}\\generic-worker.exe"

      $desired_proxy_version = lookup('win-worker.taskcluster.proxy.version')
      $proxy_name            = lookup('win-worker.taskcluster.proxy.name')

      # Livelog command does not have a version flag
      # Locking the version file name
      $livelog_name          = lookup('win-worker.taskcluster.livelog.name')
      $livelog_version       = lookup('win-worker.taskcluster.livelog.version')

      $worker_runner_dir     = lookup('windows.dir.worker_runner')
      $runner_name           = lookup('win-worker.taskcluster.worker_runner.name')
      $desired_rnr_version   = lookup('win-worker.taskcluster.worker_runner.version')
      $runner_log            = "${worker_runner_dir}\\worker-runner-service.log"
      $provider              = lookup('win-worker.taskcluster.worker_runner.provider')
      $implementation        = lookup('win-worker.taskcluster.worker_runner.implementation')

      case $provider {
        'standalone': {
          $taskcluster_root_url  = lookup('windows.taskcluster.root_url')
          $client_id             = lookup('win-worker.taskcluster.client_id')
          $access_token          = lookup('taskcluster_access_token')
          $worker_pool_id        = lookup('win-worker.taskcluster.worker_pool_id')
          $worker_group          = lookup('win-worker.taskcluster.worker_group')
          $worker_pool_id        = $facts['custom_win_worker_pool_id']
          $worker_id             = $facts['networking']['hostname']
        }
        default: {
          $taskcluster_root_url  = undef
          $client_id             = undef
          $access_token          = undef
          $worker_pool_id        = undef
          $worker_group          = undef
          $worker_id             = undef
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
        gw_exe_source      => "${ext_pkg_src_loc}/${desired_gw_version}/${gw_name}",
        gw_exe_path        => $gw_exe_path,
      }
      class { 'win_taskcluster::proxy':
        generic_worker_dir    => $generic_worker_dir,
        desired_proxy_version => $desired_proxy_version,
        current_proxy_version => $facts['custom_win_taskcluster_proxy_version'],
        proxy_exe_source      => "${ext_pkg_src_loc}/${desired_proxy_version}/${proxy_name}",
      }
      class { 'win_taskcluster::livelog':
        generic_worker_dir => $generic_worker_dir,
        livelog_exe_source => "${ext_pkg_src_loc}/${livelog_version}/${livelog_name}",
      }
      class { 'win_taskcluster::worker_runner':
        # Runner EXE
        worker_runner_dir      => $worker_runner_dir,
        desired_runner_version => $desired_rnr_version,
        current_runner_version => $facts['custom_win_runner_version'],
        runner_exe_source      => "${ext_pkg_src_loc}/${desired_rnr_version}/${runner_name}",
        runner_exe_path        => "${worker_runner_dir}\\start-worker.exe",
        runner_yml             => "${worker_runner_dir}\\runner.yml",
        # Runner service install
        gw_exe_path            => $gw_exe_path,
        runner_log             => $runner_log,
        nssm_exe               => $nssm_exe,
        # Runner yaml file
        provider               => $provider,
        implementation         => $implementation,
        root_url               => $taskcluster_root_url,
        client_id              => $client_id,
        worker_pool_id         => $worker_pool_id,
        worker_group           => $worker_group,
        worker_id              => $worker_id,
        config_file            => "${generic_worker_dir}\\generic-worker.config",
      }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
