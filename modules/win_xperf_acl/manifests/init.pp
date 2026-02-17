class win_xperf_acl (
  String $group_name = 'Mozilla XPerf Users',
  String $xperf_path = 'C:/Program Files (x86)/Windows Kits/10/Windows Performance Toolkit/xperf.exe',
) {

  # Create the local group
  group { $group_name:
    ensure => present,
  }

  # Ensure xperf exists (fail early if it doesn't)
  file { $xperf_path:
    ensure => file,
  }

  # Grant execute rights to the group on xperf.exe
  acl { $xperf_path:
    purge       => false,
    permissions => [
      {
        identity  => $group_name,
        rights    => ['read', 'execute'],
        perm_type => 'allow',
      },
    ],
    require     => [
      Group[$group_name],
      File[$xperf_path],
    ],
  }
}
