# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::backups {

    case $::operatingsystem {
        'Darwin': {

            $borgmatic_config               = lookup('borgmatic_config')
            $borgmatic_hour                 = lookup('borgmatic_hour')
            $borgmatic_minute               = lookup('borgmatic_minute')
            $borgmatic_ssh_public_key       = lookup('borgmatic_ssh_public_key')
            $borgmatic_ssh_private_key      = lookup('borgmatic_ssh_private_key')
            $borgmatic_ssh_private_key_path = lookup('borgmatic_ssh_private_key_path')

            class { 'borgmatic':
                config               => $borgmatic_config,
                hour                 => $borgmatic_hour,
                minute               => $borgmatic_minute,
                ssh_public_key       => $borgmatic_ssh_public_key,
                ssh_private_key      => $borgmatic_ssh_private_key,
                ssh_private_key_path => $borgmatic_ssh_private_key_path,
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
