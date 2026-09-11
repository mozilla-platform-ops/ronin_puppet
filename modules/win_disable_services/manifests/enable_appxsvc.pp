# win_disable_services/manifests/enable_appxsvc.pp
#
# Deploy-time counterpart to win_disable_services::disable_appxsvc, for the ref /
# ref-alpha hardware pools ONLY.
#
# Those pools must keep AppXSvc usable: the task_* user Firefox runs as needs the
# HEVC/AV1/VP9/WebMedia Store extensions REGISTERED for it, and per-user registration
# of a provisioned MSIX is done by AppXSvc at first logon. With the service disabled
# the extensions stay provisioned-but-never-installed and Firefox loses WMF hardware
# decode, failing mochitest-media-mda-gpu (bug 2013985 / RELOPS-2487).
#
# Simply NOT including disable_appxsvc is insufficient on a pre-baked install.wim: the
# bake runs disable_appxsvc, so the image already carries AppXSvc Start=4 AND the
# \Hardening\Hard-Disable-AppXSvc at-startup task. Both have to be actively undone here.
class win_disable_services::enable_appxsvc {

  $ronin_base      = $facts['custom_win_roninprogramdata']
  $svc_script_path = "${ronin_base}\\win_enable_appxsvc.ps1"

  file { $svc_script_path:
    ensure  => file,
    content => file('win_disable_services/appxpackages/win_enable_appxsvc.ps1'),
  }

  exec { 'enable_appxsvc':
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
