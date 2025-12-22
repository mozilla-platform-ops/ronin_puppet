# This class is responsible for disabling AppX packages on Windows.
class win_disable_services::uninstall_appx_packages {

  # Use the fact directly as the base path
  $ronin_base  = $facts['custom_win_roninprogramdata']
  $script_path = "${ronin_base}\\win_uninstall_appx_packages.ps1"

  ## Run file locally so that it runs as a script
  ## and not a single command
  file { $script_path:
    ensure  => file,
    content => file('win_disable_services/appxpackages/uninstall.ps1'),
  }

  exec { 'disable_appx_packages':
    command   => "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"${script_path}\"",
    provider  => shell,
    timeout   => 300,
    logoutput => true,
    returns   => [0],
    require   => File[$script_path],
  }
}
