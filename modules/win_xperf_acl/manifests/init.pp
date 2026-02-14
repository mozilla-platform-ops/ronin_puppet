class win_xperf_acl (
  String $group_name = 'Mozilla XPerf Users',
  String $xperf_path = 'C:/Program Files (x86)/Windows Kits/10/Windows Performance Toolkit/xperf.exe',
) {

  # Create the local group
  group { $group_name:
    ensure => present,
  }

  # Make the run idempotent and readable: fail early if xperf isn't there.
  # (If you prefer "skip if missing", we can change this to a conditional.)
  file { $xperf_path:
    ensure => file,
  }

  # Grant execute rights to the group on xperf.exe
  #
  # puppetlabs-acl is available in this repo/branch. :contentReference[oaicite:1]{index=1}
  acl { $xperf_path:
    purge       => false,
    permissions => [
      {
        identity => $group_name,
        rights   => ['read', 'execute'],
        type     => 'allow',
      },
    ],
    require     => [
      Group[$group_name],
      File[$xperf_path],
    ],
  }
}
