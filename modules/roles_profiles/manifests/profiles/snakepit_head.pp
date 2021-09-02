# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::snakepit_head {

    case $::operatingsystem {
        'Ubuntu':{
            include snakepit::head
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
