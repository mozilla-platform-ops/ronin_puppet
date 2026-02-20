class win_disable_services::extended_uninstall_appx_packages {

  $ronin_base       = $facts['custom_win_roninprogramdata']
  $appx_script_path = "${ronin_base}\\win_uninstall_appx_packages.ps1"
  $svc_script_path  = "${ronin_base}\\win_disable_appxsvc.ps1"

  # Hardcoded module file names (no params)
  file { $appx_script_path:
    ensure  => file,
    content => file('win_disable_services/appxpackages/win_uninstall_appx_packages.ps1'),
  }

  file { $svc_script_path:
    ensure  => file,
    content => file('win_disable_services/appxpackages/win_disable_appxsvc.ps1'),
  }

  exec { 'remove_extended_appx_packages':
    command   => "powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"${appx_script_path}\"",
    timeout   => 1200,
    logoutput => true,
    returns   => [0],
    require   => File[$appx_script_path],
    tries     => 2,
    try_sleep => 30,
  }

  exec { 'disable_appxsvc':
    command   => "powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"${svc_script_path}\"",
    timeout   => 300,
    logoutput => true,
    returns   => [0],
    require   => [File[$svc_script_path], Exec['remove_extended_appx_packages']],
    tries     => 2,
    try_sleep => 15,
  }
}
