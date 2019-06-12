# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::notarization_users {
    case $::operatingsystem {
        'Darwin': {
            include sudo
            # Make sure the users profile is required
            # That is where the user virtual resources are generated
            require roles_profiles::profiles::users
            # Lookup the group array and realize their user resource
            $users = lookup('user_groups.notarization', Array, undef, undef)
            realize(Users::Single_user[$users])

            # Monkey patching directoryservice.rb in order to create users also breaks group merging
            # So we directly add the user to the group(s)
            $users.each |String $user| {
                exec { "${user}_developer_group":
                    command => "/usr/bin/dscl . -append /Groups/admin GroupMembership ${user}",
                    unless  => "/usr/bin/groups ${user} | /usr/bin/grep -q -w _developer",
                    require => User[$user],
                }
                macos_utils::clean_appstate { $user:
                  user  => $user,
                  group => 'staff',
                }

                sudo::customfile { "sudo_to_${user}":
                  content => "cltbld ALL=(${user}) NOPASSWD: ALL\n";
                }
            }
            # Enable DevToolsSecurity
            include macos_utils::enable_dev_tools_security

        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
