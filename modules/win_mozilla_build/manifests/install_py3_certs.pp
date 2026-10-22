# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Old pip and certifi trust the compromised emSign ECC Root CA - G3, so upgrade
# pip first, then upgrade certifi to the latest release (see bug 1662170).
class win_mozilla_build::install_py3_certs (
  String $pip,
) {
  require win_mozilla_build::install

  $python   = 'C:\\mozilla-build\\python3\\python3.exe'
  $packages = 'C:\\mozilla-build\\python3\\Lib\\site-packages'

  exec { 'install_py3_pip':
    command => "${python} -m pip install pip==${pip}",
    creates => "${packages}\\pip-${pip}.dist-info",
  }

  exec { 'install_py3_certi':
    command => "${python} -m pip install --upgrade certifi",
    require => Exec['install_py3_pip'],
  }
}
