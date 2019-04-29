# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::cia_users {

    case $::operatingsystem {
        'Ubuntu': {
            # Make sure the users profile is required
            # That is where the user virtual resources are generated
            require roles_profiles::profiles::users
            # Lookup the cia group array and realize their user resource
            $relops = lookup('user_groups.cia', Array, undef, undef)
            realize(Users::Single_user[$relops])

            # add groups
            $relops.each |String $user| {
                group { $user:
                        ensure => 'present',
                }
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
