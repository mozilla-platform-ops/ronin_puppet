# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::relops_users {

    case $::operatingsystem {
        'Darwin': {
            # Make sure the users profile is required
            # That is where the user virtual resources are generated
            require roles_profiles::profiles::users
            # Lookup the relops group array and realize their user resource
            $relops = lookup('user_groups.relops', Array, undef, undef)
            realize(Users::Single_user[$relops])

            # Monkey patching directoryservice.rb in order to create users also breaks group merging
            # So we directly add the user to the group(s)
            $relops.each |String $user| {
                exec { "${user}_admin_group":
                    command => "/usr/bin/dscl . -append /Groups/admin GroupMembership ${user}",
                    unless  => "/usr/bin/groups ${user} | /usr/bin/grep -q -w admin",
                    require => User[$user],
                }
            }
        }
        'Ubuntu': {
            # Make sure the users profile is required
            # That is where the user virtual resources are generated
            require roles_profiles::profiles::users
            # Lookup the relops group array and realize their user resource
            $relops = lookup('user_groups.relops', Array, undef, undef)
            realize(Users::Single_user[$relops])

            group { 'create admin group':
                ensure => 'present',
                name   => 'admin',
            }

            # add groups
            $relops.each |String $user| {
                group { $user:
                        ensure => 'present',
                }

                # is there a way to do with virtual resources?
                # see https://serverfault.com/questions/416254/adding-an-existing-user-to-a-group-with-puppet
                exec { "${user} admin membership":
                    unless  => "/bin/grep -q 'admin\\S*${user}' /etc/group",
                    command => "/usr/sbin/usermod -aG admin ${user}",
                    require => User[$user],
                }
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
