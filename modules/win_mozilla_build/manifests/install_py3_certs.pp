# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

## CLEAN UP: lookups should be in the profile and passed to this class.

# Old pip and certifi trust the compromised emSign ECC Root CA - G3, so install
# pip by hash first, then use it to install certifi (see bug 1662170).
class win_mozilla_build::install_py3_certs {
  require win_mozilla_build::install

  $python   = 'C:\\mozilla-build\\python3\\python3.exe'
  $packages = 'C:\\mozilla-build\\python3\\Lib\\site-packages'
  $pip      = lookup('windows.mozilla_build.py3_pip_version')
  $certifi  = lookup('windows.mozilla_build.certifi_version')
  $pip_whl  = 'https://files.pythonhosted.org/packages/3f/06/3e4420302363fbb71be3c7f35ce042f54bfca330e3e66b3a2e3c4cca579f/pip-26.2.2-py3-none-any.whl#sha256=fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70'

  exec { 'install_py3_pip':
    command => "${python} -m pip install ${pip_whl}",
    creates => "${packages}\\pip-${pip}.dist-info",
  }

  exec { 'install_py3_certi':
    command => "${python} -m pip install certifi==${certifi}",
    creates => "${packages}\\certifi-${certifi}.dist-info",
    require => Exec['install_py3_pip'],
  }
}
