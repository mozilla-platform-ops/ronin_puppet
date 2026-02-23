# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# handles installation of mercurial on linux (via pkg and pip)
class linux_packages::mercurial ( Enum['present', 'absent'] $pkg_ensure = 'present') {
  case $facts['os']['name'] {
    'Ubuntu': {
      case $facts['os']['release']['full'] {
        '18.04': {
          include linux_packages::python2_mercurial
          include linux_packages::python3_mercurial

          # the binary just calls the installed python module,
          # but it points at py2 on 1804

          package {
            'mercurial':
              ensure => $pkg_ensure;
          }
        }
        '22.04', '24.04': {
          include linux_packages::python3_mercurial

          # the binary just calls the installed python module
          package {
            'mercurial':
              ensure => $pkg_ensure;
          }
        }
        default: {
          fail("Ubuntu ${facts['os']['release']['full']} is not supported")
        }
      }
    }
    default: {
      fail("Cannot install on ${facts['os']['name']}")
    }
  }
}
