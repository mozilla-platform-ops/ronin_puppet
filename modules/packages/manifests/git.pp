# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::git (
  String $version = '2.47.1',
) {
  $tarball = "git-${version}.tar.gz"
  $src_dir = "/tmp/git-${version}"
  $tmp_tar = "/tmp/${tarball}"
  $url     = "https://mirrors.edge.kernel.org/pub/software/scm/git/${tarball}"

  exec { 'download_git_src':
    command => "curl -fL -o ${tmp_tar} ${url}",
    path    => ['/usr/bin', '/bin'],
    unless  => "/usr/local/bin/git --version 2>/dev/null | grep -qF 'git version ${version}'",
    timeout => 120,
  }

  exec { 'extract_git_src':
    command => "tar -xzf ${tmp_tar} -C /tmp",
    path    => ['/usr/bin', '/bin'],
    unless  => "/usr/local/bin/git --version 2>/dev/null | grep -qF 'git version ${version}'",
    require => Exec['download_git_src'],
  }

  exec { 'build_and_install_git':
    command => './configure --prefix=/usr/local --without-tcltk && make -j4 all && make install',
    cwd     => $src_dir,
    path    => ['/usr/bin', '/usr/local/bin', '/bin', '/usr/sbin', '/sbin'],
    unless  => "/usr/local/bin/git --version 2>/dev/null | grep -qF 'git version ${version}'",
    require => Exec['extract_git_src'],
    timeout => 600,
  }
}
