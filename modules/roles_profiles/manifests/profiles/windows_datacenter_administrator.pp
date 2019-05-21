# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::windows_datacenter_administrator {

    case $::operatingsystem {
        'Windows': {

            $admin_password = lookup('win_adminpw')

            include win_users::administrator::account

            class { 'win_users::user_ssh_config ':
                home => "${facts['custom_win_systemdrive']}\\administrator",
            }

        }

        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
