# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::grant_symlink_access {
  $module_dir = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\Modules"
  # Original source https://github.com/webmd-health-services/Carbon
  # Repackaged into a zip file that can be extracted directly into Powershell module directory
  win_packages::win_zip_pkg { 'carbon':
    pkg         => 'carbon.zip',
    creates     => "${module_dir}\\Carbon\\Import-Carbon.ps1",
    destination => $module_dir,
  }

  # Using puppetlabs-powershell
  exec { 'grant_symlnk_access':
    command     => file('win_mozilla_build/grant_symlink_access.ps1'),
    provider    => powershell,
    subscribe   => Exec['carbon.zip'],
    refreshonly => true,
  }
}
