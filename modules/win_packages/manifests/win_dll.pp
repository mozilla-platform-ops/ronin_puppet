# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_packages::win_dll (
  String $dll_name,
  String $package=$title
) {
  $pkgdir = $facts['custom_win_roninprogramdata']

  case $facts['custom_win_location'] {
    'datacenter': {
      $srcloc       = lookup('windows.s3.ext_pkg_src')
    }
    default: {
      $srcloc = lookup('windows.ext_pkg_src')
    }
  }

  $url         = "${srcloc}/${dll_name}"

  archive { $title:
    ensure  => 'present',
    source  => $url,
    path    => "${pkgdir}\\${dll_name}",
    creates => "${pkgdir}\\${dll_name}",
    cleanup => false,
    extract => false,
  }

  exec { 'install_dll':
    command  => file("win_packages/install_dll.ps1 -Path ${pkgdir}\\${dll_name}"),
    provider => powershell,
  }
}
# Bug List
# https://bugzilla.mozilla.org/show_bug.cgi?id=1857116
