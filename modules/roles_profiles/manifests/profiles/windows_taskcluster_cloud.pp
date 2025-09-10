# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::windows_taskcluster_cloud {
  ## NSSM
  $nssm_dir              = lookup('windows.dir.nssm')
  $nssm_version          = lookup('windows.nssm.version')
  $nssm_exe              = "${nssm_dir}\\nssm-${nssm_version}\\${arch}\\nssm.exe"

  ## External URLs
  $ext_pkg_src_loc       = lookup('windows.taskcluster.package_source')

  ## Taskcluster variables from hiera
  $taskcluster_version    = lookup(['win-worker.variant.taskcluster.version', 'windows.taskcluster.version'])
  $taskcluster_root_url  = lookup('windows.taskcluster.root_url')

  ## Generic Worker
  $generic_worker_dir    = lookup('windows.dir.generic_worker')
  $gw_name               = lookup('windows.taskcluster.generic-worker.name.amd64')

  ## Livelog
  $livelog_name          = lookup('windows.taskcluster.livelog.name.amd64')

  ## Proxy
  $proxy_name            = lookup('windows.taskcluster.proxy.name.amd64')

  ## Worker Runner
  $worker_runner_dir     = lookup('windows.dir.worker_runner')
  $worker_runner_name    = lookup('windows.taskcluster.worker_runner.name.amd64')
  $worker_runner_provider = lookup('windows.taskcluster.worker_runner.provider')
  $worker_runner_log            = "${worker_runner_dir}\\worker-runner-service.log"
  $worker_runner_implementation        = lookup('windows.taskcluster.worker_runner.implementation')
  $worker_runner_yaml_path = "${worker_runner_dir}\\runner.yml"
  $worker_runner_nssm_service_start = 'SERVICE_AUTO_START'
  $worker_runner_nssm_service_type  = 'SERVICE_WIN32_OWN_PROCESS'
  $worker_runner_nssm_app_exit      = 'Default Exit'
  $runner_log            = "${worker_runner_dir}\\worker-runner-service.log"

  ## Taskcluster paths
  $cache_dir             = "${facts['custom_win_systemdrive']}\\\\cache"
  $gw_log_file           = "${generic_worker_dir}\\generic-worker-service.log"
  $gw_exe_path           = "${generic_worker_dir}\\generic-worker.exe"
  $worker_runner_exe_path       = "${worker_runner_dir}\\start-worker.exe"
  $downloads_dir         = "${facts['custom_win_systemdrive']}\\\\downloads"
  $ed25519signingkey_path     = "${facts['custom_win_systemdrive']}\\\\generic-worker\\\\ed25519-private.key"
  $cache_dir             = "${facts['custom_win_systemdrive']}\\\\cache"
  $gw_config_file        = "${generic_worker_dir}\\generic-worker-config.yml"
  $gw_app_parameters     = "run --config ${gw_config_file} --worker-runner-protocol-pipe \\\\.\\pipe\\generic-worker --with-worker-runner"
  $gw_nssm_service_start = 'SERVICE_DEMAND_START'
  $gw_nssm_service_type  = 'SERVICE_WIN32_OWN_PROCESS'
  $gw_nssm_app_exit      = 'Default Exit'

  ## Facts from modules/win_shared/facts.d/*
  $livelog_exe           = "${facts['custom_win_systemdrive']}\\\\generic-worker\\\\livelog.exe"
  $location              = $facts['custom_win_location']
  $task_dir              = "${facts['custom_win_systemdrive']}\\\\"
  $task_user_init_cmd    = "${generic_worker_dir}\\\\task-user-init.cmd"
  $taskcluster_proxy_exe = "${facts['custom_win_systemdrive']}\\\\generic-worker\\\\taskcluster-proxy.exe"
  $worker_id             = $facts['networking']['hostname']
  $worker_pool_id        = $facts['custom_win_worker_pool_id']
  if $facts['os']['architecture'] == 'x86' {
    $arch = 'win32'
  } else {
    $arch = 'win64'
  }

  ## Standalone variables
  $init                  = 'task-user-init.cmd'
  $worker_group          = 'mdc1'

  class { 'win_packages::custom_nssm':
    version  => $nssm_version,
    nssm_exe => $nssm_exe,
    nssm_dir => $nssm_dir,
  }

  class { 'win_taskcluster_cloud::generic_worker' :
    generic_worker_dir     => $generic_worker_dir,
    gw_exe_source          => "${ext_pkg_src_loc}/v${taskcluster_version}/${gw_name}",
    gw_exe_path            => $gw_exe_path,
    init_file              => $init,
    nssm_exe               => $nssm_exe,
    gw_app_parameters      => $gw_app_parameters,
    gw_nssm_service_start  => $gw_nssm_service_start,
    gw_nssm_service_type   => $gw_nssm_service_type,
    gw_nssm_app_exit       => $gw_nssm_app_exit,
    gw_log_file            => $gw_log_file,
    ed25519signingkey      => 'ed25519-private.key',
    ed25519signingkey_path => $ed25519signingkey_path,
  }

  class { 'win_taskcluster_cloud::proxy':
    proxy_exe_path   => $taskcluster_proxy_exe,
    proxy_exe_source => "${ext_pkg_src_loc}/v${taskcluster_version}/${proxy_name}",
  }

  class { 'win_taskcluster_cloud::livelog':
    livelog_exe_path   => $livelog_exe,
    livelog_exe_source => "${ext_pkg_src_loc}/v${taskcluster_version}/${livelog_name}",
  }

  class { 'win_taskcluster_cloud::worker_runner':
    worker_runner_dir                => $worker_runner_dir,
    worker_runner_exe_path           => $worker_runner_exe_path,
    worker_runner_exe_source         => "${ext_pkg_src_loc}/v${taskcluster_version}/${$worker_runner_name}",
    worker_runner_yaml_path          => $worker_runner_yaml_path,
    worker_runner_nssm_service_start => $worker_runner_nssm_service_start,
    worker_runner_nssm_service_type  => $worker_runner_nssm_service_type,
    worker_runner_nssm_app_exit      => $worker_runner_nssm_app_exit,
    worker_runner_log                => $worker_runner_log,
  }
}
