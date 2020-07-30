# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::virtual_drivers {

    case $::operatingsystem {
        'Windows': {
            class { 'win_packages::vbcable':
                directory => "${facts['custom_win_systemdrive']}\\vbcable_driver",
                version   => lookup('win-worker.vbcable.version') ,

            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1656286
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
