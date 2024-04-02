# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_packages::win_exe_pkg (
  String $pkg,
  String $creates,
  String $install_options_string,
  String $package=$title
) {
  $pkgdir       = $facts['custom_win_temp_dir']
  $srcloc       = lookup('windows.ext_pkg_src')
  $url         = "${srcloc}/${pkg}"

  download_file { $package :
    url                   => $url,
    destination_directory => $pkgdir,
    destination_file      => $pkg,
  }

  exec { "${title}install":
    command => "${pkgdir}\\${pkg} ${install_options_string}",
    creates => $creates,
    timeout => 600,
  }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=1520895

# TODO
# Add a programatic check to verify the package is installed
# Add the ability to check the version
