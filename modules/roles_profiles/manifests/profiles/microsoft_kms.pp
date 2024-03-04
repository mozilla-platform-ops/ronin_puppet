# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::microsoft_kms {

    case $::operatingsystem {
        'Windows': {
            if $facts['custom_win_kms_activated'] != 'activated' {
                $key = lookup("windows.kms.key.${facts['custom_win_os_caption']}")
                class {  'win_kms::set_key':
                    key => $key,
                }
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
