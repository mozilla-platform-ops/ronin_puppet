# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::hardware {

    case $::operatingsystem {
        'Darwin': {

            # Lookup the apple firmware acceptance hash and assert the hosts firmware
            $apple_firmware_acceptance = lookup('apple_firmware_acceptance', Hash)
            class { 'macos_utils::assert_firmware':
                acceptance_hash => $apple_firmware_acceptance,
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
