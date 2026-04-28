# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_hw_profiling::xperf_kernel_trace {

  $script_dir = $facts['custom_win_roninprogramdata']
  $ps         = "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0\\powershell.exe"

  $xperf_start_ps1 = "${script_dir}\\xperf_kernel_start.ps1"
  $xperf_stop_ps1  = "${script_dir}\\xperf_kernel_stop.ps1"
  $xperf_setup_ps1 = "${script_dir}\\xperf_register_tasks.ps1"

  file { $xperf_start_ps1:
    ensure  => file,
    content => file('win_hw_profiling/xperf_kernel_start.ps1'),
  }

  file { $xperf_stop_ps1:
    ensure  => file,
    content => file('win_hw_profiling/xperf_kernel_stop.ps1'),
  }

  file { $xperf_setup_ps1:
    ensure  => file,
    content => file('win_hw_profiling/xperf_register_tasks.ps1'),
  }

  # Run ONLY when scripts change (first apply counts as a change)
  exec { 'xperf_register_tasks':
    command     => "${ps} -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"${xperf_setup_ps1}\" -StartScript \"${xperf_start_ps1}\" -StopScript \"${xperf_stop_ps1}\"",
    provider    => powershell,
    logoutput   => true,
    refreshonly => true,
    subscribe   => [
      File[$xperf_start_ps1],
      File[$xperf_stop_ps1],
      File[$xperf_setup_ps1],
    ],
  }
}
