# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_packages::win_zip_pkg (
  String $pkg,
  String $destination,
  String $creates,
  String $package=$title
) {
  require win_packages::sevenzip

  case $facts['custom_win_location'] {
    'datacenter': {
      $srcloc = lookup('windows.s3.ext_pkg_src')
    }
    default: {
      $srcloc = lookup('windows.ext_pkg_src')
    }
  }

  $pkgdir      = $facts['custom_win_temp_dir']
  $seven_zip   = "\"${facts['custom_win_programfiles']}\\7-Zip\\7z.exe\""
  $source      = "\"${pkgdir}\\${pkg}\""
  $url         = "${srcloc}/${pkg}"

  # Use https://github.com/voxpupuli/puppet-archive instead of built-in file resource type to download files
  archive { $title:
    ensure  => 'present',
    source  => $url,
    path    => "${pkgdir}\\${pkg}",
    creates => "${pkgdir}\\${pkg}",
    cleanup => false,
    extract => false,
  }

  file { $destination:
    ensure => directory,
  }
  # Unzip resources from Forge will fail when Puppet is ran
  # as system  in a schedule task. This is because of the context
  # powershell is ran in.
  exec { $pkg:
    command => "${seven_zip} x ${source} -o${destination} -y",
    creates => $creates,
  }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1520038
