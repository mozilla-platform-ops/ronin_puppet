# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_scheduled_tasks::clean_profilelist {

    $clean_profilelist_ps1 = "${facts['custom_win_roninprogramdata']}\\clean_profilelist.ps1"

    if $::operatingsystem == 'Windows' {
        file { $clean_profilelist_ps1:
            content => file('win_scheduled_tasks/clean_profilelist.ps1'),
        }
        # Resource from puppetlabs-scheduled_task
        scheduled_task { 'clean_profilelist':
            ensure    => 'present',
            command   => "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0\\powershell.exe",
            arguments => "-File ${clean_profilelist_ps1}",
            enabled   => true,
            trigger   => [{
                'schedule' => 'logon',
                'user_id'  => ''
            }],
            user      => 'system',
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
