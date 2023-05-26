# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_maintenance_service::install {
  win_packages::win_exe_pkg { 'mozilla_maintenance_service':
    pkg                    => 'maintenanceservice_installer.exe',
    install_options_string => '/S',
    creates                => "C:\\Program Files (x86)\\Mozilla Maintenance Service\\Uninstall.exe",
  }
  ## Fails without rebooting, possible workaround is to have a powershell exec
  exec { 'mozilla_maintenance_acl':
    command   => file('win_mozilla_maintenance_service/acl.ps1'),
    onlyif    => file('win_mozilla_maintenance_service/aclvalidate.ps1'),
    provider  => powershell,
    logoutput => true,
    timeout   => 300,
  }
}
