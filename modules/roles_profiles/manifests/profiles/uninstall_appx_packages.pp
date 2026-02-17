# This class is responsible for disabling AppX packages on Windows.
class win_disable_services::uninstall_appx_packages (
  $apx_uninstall
) {
  $ronin_base  = $facts['custom_win_roninprogramdata']
  $script_path = "${ronin_base}\\win_uninstall_appx_packages.ps1"

  file { $script_path:
    ensure  => file,
    content => file("win_disable_services/appxpackages/${apx_uninstall}"),
  }

  exec { 'disable_appx_packages':
    # Call the script file from PowerShell provider
    command   => "& '${script_path}'",
    provider  => powershell,
    timeout   => 300,
    logoutput => true,
    returns   => [0],
    require   => File[$script_path],
    tries     => 1,
  }
}
