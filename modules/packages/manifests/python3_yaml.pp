# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::python3_yaml (
  String $version = '6.0.2',
) {
  require packages::python3

  exec { 'install_pyyaml':
    command => "/Library/Frameworks/Python.framework/Versions/3.11/bin/pip3 install pyyaml==${version}",
    unless  => "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3 -c 'import yaml; print(yaml.__version__)' | grep -q ${version}",
    path    => ['/Library/Frameworks/Python.framework/Versions/3.11/bin', '/usr/local/bin', '/usr/bin'],
    timeout => 300,
    require => Class['packages::python3'],
  }
}
