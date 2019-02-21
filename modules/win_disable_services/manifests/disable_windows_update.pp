# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_windows_update {

    if $::operatingsystem == 'Windows' {
        win_disable_services::disable_service { 'wuauserv':
        }
        registry::value { 'SearchOrderConfig':
            key  => 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching',
            type => dword,
            data => '0',
        }
        registry::value { 'NoAutoUpdate':
            key  => 'HKLM\SOFTWARE\Microsoft\Windows\Windows\AU',
            type => dword,
            data => '1',
        }
        registry::value { 'AUOptions':
            key  => 'HKLM\SOFTWARE\Microsoft\Windows\Windows\AU',
            type => dword,
            data => '2'
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
    # Bug List
    # https://bugzilla.mozilla.org/show_bug.cgi?id=1510756
}
