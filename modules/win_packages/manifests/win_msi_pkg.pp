# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_packages::win_msi_pkg (
  String $pkg,
  Array $install_options,
  String $package=$title
) {
  $pkgdir = $facts['custom_win_temp_dir']
  $srcloc = lookup('windows.ext_pkg_src')
  $url = "${srcloc}/${pkg}"

  notify { "${package} download message":
    message => "Downloading ${pkg} from ${url} to ${pkgdir}",
  }

  archive { $title:
    ensure  => 'present',
    source  => $url,
    path    => "${pkgdir}\\${pkg}",
    creates => "${pkgdir}\\${pkg}",
    cleanup => false,
    extract => false,
  }

  package { $title :
    ensure          => installed,
    source          => "${pkgdir}\\${pkg}",
    install_options => $install_options,
  }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1519928
