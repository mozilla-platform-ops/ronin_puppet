# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::python3_zstandard (
  String $version = '0.11.1',
) {
  require packages::python3
  require macos_xcode_tools

  package { 'python3-zstandard':
    ensure   => $version,
    name     => 'zstandard',
    provider => pip3,
    require  => Class['packages::python3', 'macos_xcode_tools'],
  }
}
