# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define signing_worker::notarization_user (
  String $user,
) {
    case $::operatingsystem {
        'Darwin': {
            # Make sure the users profile is required
            # That is where the user virtual resources are generated
            require roles_profiles::profiles::users
            realize(Users::Single_user[$user])

            exec { "${user}_developer_group":
                command => "/usr/bin/dscl . -append /Groups/_developer GroupMembership ${user}",
                unless  => "/usr/bin/groups ${user} | /usr/bin/grep -q -w _developer",
                require => User[$user],
            }
            macos_utils::clean_appstate { $user:
              user  => $user,
              group => 'staff',
            }
            # Enable DevToolsSecurity
            include macos_utils::enable_dev_tools_security
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
