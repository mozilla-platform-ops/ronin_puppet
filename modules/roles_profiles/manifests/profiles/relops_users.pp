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
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
