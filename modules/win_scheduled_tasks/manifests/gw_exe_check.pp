# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_scheduled_tasks::gw_exe_check (
) {

    $gw_exe_check_ps1 = "${facts['custom_win_roninprogramdata']}\\gw_exe_check.ps1"

    file { $gw_exe_check_ps1:
        content => file('win_scheduled_tasks/gw_exe_check.ps1'),
    }
    # Resource from puppetlabs-scheduled_task
    scheduled_task { 'gw_exe_check':
        ensure    => 'present',
        command   => "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0\\powershell.exe",
        arguments => "-executionpolicy bypass -File ${gw_exe_check_ps1}",
        enabled   => true,
        trigger   => [{
            'schedule'         => 'boot',
            'minutes_interval' => '0',
            'minutes_duration' => '0'
        }],
        user      => 'system',
    }
}
