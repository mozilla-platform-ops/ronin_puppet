# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::vnc {

    case $::operatingsystem {
        'Windows': {

            $package  = 'UltraVnc'
            $msi      = 'UltraVnc_1223_X64.msi'
            $ini_file = "${facts['custom_win_programfiles']}\\UltraVNC\\ultravnc.ini"
            $port     = '5900'
            $pw_hash  = lookup('win_vncpw_hash')
            $mdc1_jh1 = lookup('win_mdc1_jh1_ip')
            $mdc1_jh2 = lookup('win_mdc1_jh2_ip')
            $mdc2_jh1 = lookup('win_mdc2_jh1_ip')
            $mdc2_jh2 = lookup('win_mdc2_jh2_ip')

            if $facts['custom_win_location'] == 'datacenter' {
                if $facts['custom_win_mozspace'] == 'mdc1' {
                    $jumphosts = "${mdc1_jh1}, ${mdc1_jh2}"
                } if $facts['custom_win_mozspace'] == 'mdc2' {
                    $jumphosts = "${mdc2_jh1}, ${mdc2_jh2}"
                } else {
                    fail('Unable to determine jumphost for this location')
                }
            }

            class { 'win_ultravnc':
                package   => $package,
                msi       => $msi,
                ini_file  => $ini_file,
                pw_hash   => $pw_hash,
                port      => $port,
                jumphosts => $jumphosts,
            }
            # Bug List
            #
            # TODO Add 32 bit support
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
