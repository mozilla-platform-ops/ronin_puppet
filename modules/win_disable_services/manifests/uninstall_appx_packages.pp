# This class is responsible for disabling AppX packages on Windows.
class win_disable_services::uninstall_appx_packages {
  exec { 'disable_appx_packages':
    command  => file('win_disable_services/appxpackages/uninstall.ps1'),
    provider => powershell,
    timeout  => 300,
  }
}
