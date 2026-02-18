# modules/xperf_profiling/manifests/init.pp
#
# xperf profiling setup:
# - ensure WPT installed
# - create local group
# - grant group execute on xperf.exe
# - grant SeSystemProfilePrivilege ("Profile system performance") via shipped PS1

class xperf_profiling (
  String $group_name = 'Mozilla_XPerf_Users',
  String $xperf_path = 'C:/Program Files (x86)/Windows Kits/10/Windows Performance Toolkit/xperf.exe',
) {

  $ronin_base  = $facts['custom_win_roninprogramdata']
  $script_path = "${ronin_base}\\win_grant_system_profile_priv.ps1"

  # Ensure Windows Performance Toolkit is installed (provides xperf.exe)
  require win_packages::performance_tool_kit

  group { $group_name:
    ensure => present,
  }

  acl { $xperf_path:
    purge       => false,
    permissions => [
      {
        identity  => $group_name,
        rights    => ['read', 'execute'],
        perm_type => 'allow',
      },
    ],
    require     => Group[$group_name],
  }

  file { $script_path:
    ensure  => file,
    content => file('xperf_profiling/win_grant_system_profile_priv.ps1'),
    require => Group[$group_name],
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
