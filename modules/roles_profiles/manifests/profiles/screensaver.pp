# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::screensaver {
  case $facts['os']['name'] {
    'Darwin': {
      mac_profiles_handler::manage { 'org.mozilla.SetDefaultScreensaver':
        ensure => 'absent',
      }
      include macos_disable_screensaver
      Mac_profiles_handler::Manage['org.mozilla.SetDefaultScreensaver'] -> Class['macos_disable_screensaver']
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
