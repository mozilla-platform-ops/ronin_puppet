# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
define signing_worker::system_user (
    String $user,
    String $password,
    String $salt,
    String $iterations,
) {
    case $::operatingsystem {
        'Darwin': {

            # Create the cltbld user
            users::single_user { $user:
                # Bug 1122875 - cltld needs to be in this group for debug tests
                password   => $password,
                salt       => $salt,
                iterations => $iterations,
            }

            # Monkey patching directoryservice.rb in order to create users also breaks group merging
            # So we directly add the user to the group(s)
            exec { "${user}_developer_group":
                command => "/usr/bin/dscl . -append /Groups/_developer GroupMembership ${user}",
                unless  => "/usr/bin/groups ${user} | /usr/bin/grep -q -w _developer",
                require => User[$user],
            }

            # Set user to autologin
            #  class { 'macos_utils::autologin_user':
            #       user       => $user,
            #       kcpassword => $kcpassword,
            #   }

            # Enable DevToolsSecurity
            include macos_utils::enable_dev_tools_security

            macos_utils::clean_appstate { $user:
                user  => $user,
                group => 'staff',
            }

            mercurial::hgrc { "/Users/${user}/.hgrc":
                user    => $user,
                group   => 'staff',
                require => User[$user],
            }

            # Consider removing this if/when 'sudo su' is no longer used.
            sudo::custom { "allow_${user}_all":
                user    => $user,
                command => 'ALL',
            }

        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
