# This class is responsible for disabling AppX packages on Windows.
class win_disable_services::uninstall_appx_packages {
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
