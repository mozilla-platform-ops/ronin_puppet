# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::gpu_drivers {

    case $::operatingsystem {
        'Windows': {

            if $facts['custom_win_gpu'] == True {
                class { 'win_packages::drivers::nvidia_grid':
                    driver_name => '391.81_grid_win10_server2016_64bit_international',
                    srcloc      => lookup('windows.s3.ext_pkg_src'),
                }
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
