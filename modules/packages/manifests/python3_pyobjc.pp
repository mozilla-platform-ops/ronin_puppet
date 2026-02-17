# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::python3_pyobjc (
  String $version = '11.0',
) {
  require packages::python3
  require macos_xcode_tools

  exec { 'install_pyobjc':
    command => "/Library/Frameworks/Python.framework/Versions/3.11/bin/pip3 install pyobjc==${version}",
    unless  => "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3 -c 'import objc; print(objc.__version__)' | grep -q ${version}",
    path    => ['/Library/Frameworks/Python.framework/Versions/3.11/bin', '/usr/local/bin', '/usr/bin'],
    timeout => 900,
    require => Class['packages::python3', 'macos_xcode_tools'],
  }
}
