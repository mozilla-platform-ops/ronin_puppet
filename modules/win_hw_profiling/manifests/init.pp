class win_hw_profiling {

  $ronin_base  = $facts['custom_win_roninprogramdata']
  $script_path = "${ronin_base}\\win_grant_system_profile_priv.ps1"

  # Ensure Windows Performance Toolkit is installed (provides xperf.exe)
  require win_packages::performance_tool_kit

  file { $script_path:
    ensure  => file,
    content => file('win_hw_profiling/win_grant_system_profile_priv.ps1'),
  }

  exec { 'xperf_profiling_grant_profile_system_performance':
    command   => "& '${script_path}'",
    provider  => powershell,
    timeout   => 300,
    logoutput => true,
    returns   => [0],
    require   => File[$script_path],
    tries     => 1,
  }
}
