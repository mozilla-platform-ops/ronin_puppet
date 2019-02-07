# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::disable_system_restore {

    case $::operatingsystem {
        'Windows': {
            registry_key { 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore':
                ensure => present,
            }
            registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore\DisableConfig':
                ensure => present,
                type   => dword,
                data   => '1',
            }
            # Can not use the registry::value becuase 'DisableConfig" is common value that is used else where.
            # Bug List
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
