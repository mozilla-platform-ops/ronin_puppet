class win_hw_profiling::xperf_kernel_trace {

  $script_dir = $facts['custom_win_roninprogramdata']
  $ps         = "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0\\powershell.exe"

  $xperf_start_ps1 = "${script_dir}\\xperf_kernel_start.ps1"
  $xperf_stop_ps1  = "${script_dir}\\xperf_kernel_stop.ps1"

  file { $xperf_start_ps1:
    ensure  => file,
    content => file('win_hw_profiling/xperf_kernel_start.ps1'),
  }

  file { $xperf_stop_ps1:
    ensure  => file,
    content => file('win_hw_profiling/xperf_kernel_stop.ps1'),
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
}
