# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_hw_profiling::xperf_kernel_trace {

  $script_dir = $facts['custom_win_roninprogramdata']
  $ps         = "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0\\powershell.exe"

  $xperf_start_ps1 = "${script_dir}\\xperf_kernel_start.ps1"
  $xperf_stop_ps1  = "${script_dir}\\xperf_kernel_stop.ps1"
  $xperf_acl_ps1   = "${script_dir}\\xperf_task_acl.ps1"

  file { $xperf_start_ps1:
    ensure  => file,
    content => file('win_hw_profiling/xperf_kernel_start.ps1'),
  }

  file { $xperf_stop_ps1:
    ensure  => file,
    content => file('win_hw_profiling/xperf_kernel_stop.ps1'),
  }

  # Script that updates scheduled-task security descriptor (lets non-admin users run it)
  file { $xperf_acl_ps1:
    ensure  => file,
    content => file('win_hw_profiling/xperf_task_acl.ps1'),
  }

  scheduled_task { 'xperf_kernel_trace_start':
    ensure    => present,
    command   => $ps,
    arguments => "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"${xperf_start_ps1}\"",
    enabled   => true,
    trigger   => [], # ONDEMAND
    user      => 'SYSTEM',
    require   => File[$xperf_start_ps1],
  }

  scheduled_task { 'xperf_kernel_trace_stop':
    ensure    => present,
    command   => $ps,
    arguments => "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"${xperf_stop_ps1}\"",
    enabled   => true,
    trigger   => [], # ONDEMAND
    user      => 'SYSTEM',
    require   => File[$xperf_stop_ps1],
  }

  # Apply ACL after tasks exist so BUILTIN\Users can trigger them non-elevated
  exec { 'xperf_task_acl':
    command   => "${ps} -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"${xperf_acl_ps1}\"",
    provider  => powershell,
    logoutput => true,
    require   => [
      File[$xperf_acl_ps1],
      Scheduled_task['xperf_kernel_trace_start'],
      Scheduled_task['xperf_kernel_trace_stop'],
    ],
  }
}
