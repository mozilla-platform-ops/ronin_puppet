# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_scheduled_tasks::maintain_system {

    $maintainsystem_ps1 = "${facts['custom_win_system32']}\\maintainsystem.ps1"

    if $::operatingsystem == 'Windows' {
        file { $maintainsystem_ps1:
            content => file('win_scheduled_tasks/maintainsystem.ps1'),
        }
        # Resource from puppetlabs-scheduled_task
        scheduled_task { 'maintain_system':
            ensure    => 'present',
            command   => "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0\\powershell.exe",
            arguments => "-File ${maintainsystem_ps1}",
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
