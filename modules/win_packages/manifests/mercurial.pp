# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::mercurial {
  $needed_hg_ver = lookup('win-worker.hg.version')
  $srcloc   = lookup('windows.ext_pkg_src')

  win_packages::win_msi_pkg { "Mercurial ${needed_hg_ver}" :
    pkg             => "mercurial-${needed_hg_ver}-x64.msi",
    install_options => ['/quiet'],
  }
}
