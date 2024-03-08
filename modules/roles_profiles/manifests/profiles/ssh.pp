# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::ssh {

    case $::operatingsystem {
        'Windows': {

            $relops_key = lookup('windows.winaudit_ssh')

            include win_openssh::add_openssh

            class { 'win_users::administrator::authorized_keys':
                relops_key => $relops_key,
            }

            include win_openssh::service

            win_firewall::open_local_port { 'allow_SSH':
                port            => 22,
                reciprocal      => true,
                fw_display_name => 'Allow port 22',
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
