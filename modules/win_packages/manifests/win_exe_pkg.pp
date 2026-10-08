# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_packages::win_exe_pkg (
  String $pkg,
  String $creates,
  String $install_options_string,
  String $package=$title,
  $returns=undef
) {
  include win_packages::staging
  $pkgdir       = $win_packages::staging::path
  $srcloc       = lookup('windows.ext_pkg_src')
  $url         = "${srcloc}/${pkg}"
  $pkgpath     = "${pkgdir}\\${pkg}"

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

  exec { "${title}install":
    command => "${pkgpath} ${install_options_string}",
    creates => $creates,
    timeout => 600,
    returns => $returns,
    require => Acl[$pkgpath],
  }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1520895

# TODO
# Add a programatic check to verify the package is installed
# Add the ability to check the version
