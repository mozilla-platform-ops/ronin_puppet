# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class shared {

    # Becareful adding, removing or changing attributes within the $file_defaults.
    # They are sourced by many other modules
    case $facts['os']['name'] {
        'Darwin': {
            $file_defaults = {
                owner  => 'root',
                group  => 'wheel',
            }
        }
        'Ubuntu': {
            $file_defaults = {
                owner  => 'root',
                group  => 'root',
            }
        }
        default: {
            fail("${facts['os']['name']} is not supported")
        }
    }
}
