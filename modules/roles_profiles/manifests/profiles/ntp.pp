# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::ntp {

    case $::operatingsystem {
        'Darwin': {
            class { 'macos_ntp':
                enabled    => true,
                # ntp_server => $ntp_server,  # use time.apple.com
            }
        }
        'Windows': {
        # https://bugzilla.mozilla.org/show_bug.cgi?id=1510754
        # For windowstime resoucre timezone and server needs to be set in the same class
        # Resource from ncorrare-windowstime
            if $facts['custom_win_location'] == 'datacenter' {
                $ntpserver = lookup('win_datacenterntp')
            } else {
                $ntpserver = '0.pool.ntp.org'
            }
            class { 'windowstime':
                servers  => { "${ntpserver}" => '0x08'},
                timezone => 'Greenwich Standard Time',
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
