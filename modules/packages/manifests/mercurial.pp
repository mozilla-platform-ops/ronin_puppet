# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::mercurial (
  String $version = '6.4.5',
) {
  require packages::python3

  # Add the Python 3.11 bin directory to the system PATH permanently
  file { '/etc/paths.d/python3.11':
    ensure  => 'file',
    content => '/Library/Frameworks/Python.framework/Versions/3.11/bin',
    mode    => '0644',
  }

  # Remove /usr/local/bin/hg if it exists
  exec { 'remove_old_hg':
    command => 'rm -f /usr/local/bin/hg',
    onlyif  => 'test -f /usr/local/bin/hg',
    path    => ['/bin', '/usr/bin'],
  }

  # Ensure the path file is created and old hg binary is removed before the package is installed
  Exec['remove_old_hg'] -> File['/etc/paths.d/python3.11'] -> Package['python3-mercurial']

  package { 'python3-mercurial':
    ensure   => $version,
    name     => 'mercurial',
    provider => pip3,
    # Sometimes it seems this below is needed for macOS > 10.15 (?)
    #install_options => ['--use-pep517'],
    require  => [Class['packages::python3'], Class['macos_xcode_tools']],
  }

  # Create a symlink at /usr/local/bin/hg pointing to the new hg binary
  file { '/usr/local/bin/hg':
    ensure  => 'link',
    target  => '/Library/Frameworks/Python.framework/Versions/3.11/bin/hg',
    require => Package['python3-mercurial'],
  }
}
