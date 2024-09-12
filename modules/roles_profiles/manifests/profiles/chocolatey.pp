# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::chocolatey {
  case $facts['os']['name'] {
    'Windows': {
      #include chocolatey
      ## chocolatey doesn't seem to add to path, doing that here
      #windows_env { "PATH=C:\\ProgramData\\Chocolatey\\bin": }
      ## There are times when installing google chrome will fail due to hash mismatch
      ## This should be fixed once we internalize google chrome
      chocolateyfeature { 'checksumFiles':
        ensure => disabled,
      }
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
