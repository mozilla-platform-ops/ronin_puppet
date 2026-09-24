# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_maintenance_service::install {
  include win_packages::staging
  $local_exe = "${win_packages::staging::path}\\maintenanceservice.exe"

  file { $local_exe:
    source  => $win_mozilla_maintenance_service::source_exe,
    require => Class['win_packages::staging'],
  }
  acl { $local_exe:
    owner                      => 'S-1-5-18',
    inherit_parent_permissions => false,
    purge                      => true,
    permissions                => [
      { identity => 'S-1-5-18', rights => ['full'] },
      { identity => 'S-1-5-32-544', rights => ['full'] },
      { identity => 'S-1-5-32-545', rights => ['read', 'execute'] },
    ],
    require                    => File[$local_exe],
  }

  win_packages::win_exe_pkg { 'mozilla_maintenance_service':
    pkg                    => 'maintenanceservice_installer.exe',
    install_options_string => '/S',
    creates                => "${facts['custom_win_programfilesx86']}\\Mozilla Maintenance Service\\uninstall.exe",
    require                => Acl[$local_exe],
  }

  ## Puppet functions fails to apply without a reboot, hence the powershell exec step below
  exec { 'mozilla_maintenance_acl':
    command  => file('win_mozilla_maintenance_service/acl.ps1'),
    unless   => file('win_mozilla_maintenance_service/aclvalidate.ps1'),
    provider => powershell,
    timeout  => 300,
    require  => Win_packages::Win_exe_pkg['mozilla_maintenance_service'],
  }
}
