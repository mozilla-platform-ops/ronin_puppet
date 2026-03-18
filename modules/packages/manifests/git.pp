# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::git (
  String $version = '2.47.1',
) {
  $pkg_file = "git-${version}-intel-universal-mavericks.pkg"
  $tmp_pkg  = "/tmp/${pkg_file}"
  $url      = "https://github.com/git-osx-installer/git-osx-installer/releases/download/git-${version}/${pkg_file}"

  exec { 'download_git_pkg':
    command => "curl -L -o ${tmp_pkg} '${url}'",
    path    => ['/usr/bin', '/bin'],
    unless  => "test -x /usr/local/git/bin/git && /usr/local/git/bin/git --version 2>/dev/null | grep -qF '${version}'",
  }

  exec { 'install_git_pkg':
    command => "installer -pkg ${tmp_pkg} -target /",
    path    => ['/usr/sbin', '/usr/bin'],
    unless  => "test -x /usr/local/git/bin/git && /usr/local/git/bin/git --version 2>/dev/null | grep -qF '${version}'",
    require => Exec['download_git_pkg'],
  }
}
