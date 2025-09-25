# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::users {

    case $::operatingsystem {
        'Darwin', 'Ubuntu': {
            # Fetch a hash of all users and their keys
            # Then instant the all_users class which generates
            # virtual resources for all users to be realized in
            # other profiles based on group association
            $base_users = lookup('all_users', Hash, undef, undef)

            # Additional users such as temporary access to loaner hosts
            $additional_users = lookup('additional_users', Hash, 'first', {})

            # Merge base and additional users
            $all_users = $base_users + $additional_users

            class { 'users::all_users':
                all_users => $all_users
            }

        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
