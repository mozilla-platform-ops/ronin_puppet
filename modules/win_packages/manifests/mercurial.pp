# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::mercurial (
  String $version,
) {
  case $version {
    '6.2.1': {
      $install_opts = ['/quiet']
    }
    default: {
      $install_opts = [
        '/quiet',
        { 'INSTALLDIR' => 'C:\\Program Files\\Mercurial' },
        { 'ADDLOCAL' => 'MainProgram' },
      ]
    }
  }

  win_packages::win_msi_pkg { "Mercurial ${version}" :
    pkg             => "mercurial-${version}-x64.msi",
    install_options => $install_opts,
  }
}
