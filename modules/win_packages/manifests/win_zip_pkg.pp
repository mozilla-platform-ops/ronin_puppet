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
  include win_packages::staging

  $srcloc = lookup('windows.ext_pkg_src')

  $pkgdir      = $win_packages::staging::path
  $pkgpath     = "${pkgdir}\\${pkg}"
  $seven_zip   = "\"${facts['custom_win_programfiles']}\\7-Zip\\7z.exe\""
  $source      = "\"${pkgpath}\""
  $url         = "${srcloc}/${pkg}"

  # Use https://github.com/voxpupuli/puppet-archive instead of built-in file resource type to download files
  archive { $title:
    ensure  => 'present',
    source  => $url,
    path    => $pkgpath,
    creates => $pkgpath,
    cleanup => false,
    extract => false,
    require => Class['win_packages::staging'],
  }

  acl { $pkgpath:
    owner                      => 'S-1-5-18',
    inherit_parent_permissions => false,
    purge                      => true,
    permissions                => [
      { identity => 'S-1-5-18', rights => ['full'] },
      { identity => 'S-1-5-32-544', rights => ['full'] },
      { identity => 'S-1-5-32-545', rights => ['read', 'execute'] },
    ],
    require                    => Archive[$title],
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
    require => [Acl[$pkgpath], File[$destination]],
  }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1520038
