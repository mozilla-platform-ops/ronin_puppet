# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::software_updates {
  case $facts['os']['name'] {
    'Darwin': {
      mac_profiles_handler::manage { 'com.github.erikberglund.ProfileCreator.7AF6CC8C-EA10-4CD9-B145-77FD3CCFEF35':
        ensure => 'absent',
      }
      include macos_disable_software_updates
      Mac_profiles_handler::Manage['com.github.erikberglund.ProfileCreator.7AF6CC8C-EA10-4CD9-B145-77FD3CCFEF35'] -> Class['macos_disable_software_updates']
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }}
