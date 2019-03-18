# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::power_management {

    case $::operatingsystem {
        'Darwin': {
            macos_utils::systemsetup {
                'computersleep':
                    setting => 'Never';
                'displaysleep':
                    setting => 'Never';
                'harddisksleep':
                    setting => 'Never';
                'allowpowerbuttontosleepcomputer':
                    setting => 'off';
            }

            # Mac Mini hardware model Macmini7,1 supports additional powersettings
            if $facts['system_profiler']['model_identifier'] == 'Macmini7,1' {
                macos_utils::systemsetup {
                    'restartpowerfailure':
                        setting => 'on';
                    'wakeonnetworkaccess':
                        setting => 'on';
                    'restartfreeze':
                        setting => 'on';
                }
            }
        }
        'Windows': {
            class { 'windows::power_scheme':
                ensure => 'High performance',
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1524436
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
