# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_system_restore {

    if $::operatingsystem == 'Windows' {
        registry_key { 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore':
            ensure => present,
        }
        registry_value { 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore\DisableConfig':
            ensure => present,
            type   => dword,
            data   => '1',
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
