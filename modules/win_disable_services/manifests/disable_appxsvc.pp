# win_disable_services/manifests/disable_appxsvc.pp
class win_disable_services::disable_appxsvc {

  $ronin_base      = $facts['custom_win_roninprogramdata']
  $svc_script_path = "${ronin_base}\\win_disable_appxsvc.ps1"

  file { $svc_script_path:
    ensure  => file,
    content => file('win_disable_services/appxpackages/win_disable_appxsvc.ps1'),
  }

  exec { 'disable_appxsvc':
    command   => "& '${svc_script_path}'",
    provider  => powershell,
    timeout   => 300,
    logoutput => true,
    returns   => [0],
    require   => File[$svc_script_path],
    tries     => 2,
    try_sleep => 15,
  }
}
