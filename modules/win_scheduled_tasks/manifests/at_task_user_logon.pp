# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_scheduled_tasks::at_task_user_logon {

    $at_task_user_logon_bat = "${facts['custom_win_roninprogramdata']}\\at_task_user_logon.bat"

    if $::operatingsystem == 'Windows' {
        file { $at_task_user_logon_bat:
            content => file('win_scheduled_tasks/at_task_user_logon.bat'),
        }
        # Resource from puppetlabs-scheduled_task
        scheduled_task { 'at_task_user_logon':
            ensure    => 'present',
            command   => "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0\\cmd.exe",
            arguments => "/c ${at_task_user_logon_bat}",
            enabled   => true,
            trigger   => [{
                'schedule'         => 'boot',
                'minutes_interval' => '0',
                'minutes_duration' => '0'
            }],
            user      => 'system',
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
