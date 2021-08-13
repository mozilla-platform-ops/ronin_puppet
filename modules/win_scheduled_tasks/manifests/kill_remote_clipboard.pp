# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_scheduled_tasks::kill_remote_clipboard {

    $kill_rdpclip = "${facts['custom_win_roninprogramdata']}\\kill_rdpclip.ps1"

    if $::operatingsystem == 'Windows' {
        file { $kill_rdpclip:
            content => file('win_scheduled_tasks/kill_rdpclip.ps1'),
        }
        # Resource from puppetlabs-scheduled_task
        scheduled_task { 'kill_remote_clipboard':
            ensure    => 'present',
            command   => "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0\\powershell.exe",
            arguments => "-executionpolicy bypass -File ${kill_rdpclip}",
            enabled   => true,
            trigger   => [{
                'schedule'         => 'boot',
                'minutes_interval' => '1',
                'minutes_duration' => '60'
            }],
            user      => 'system',
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
