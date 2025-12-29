# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_scheduled_tasks::self_redeploy_check (
) {

  $script = "${facts['custom_win_roninprogramdata']}\\self_redeploy_check.ps1"

  file { $script:
    content => file('win_scheduled_tasks/self_redeploy_check.ps1'),
  }

  scheduled_task { 'self_redeploy_check':
    ensure    => 'present',
    command   => "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0\\powershell.exe",
    arguments => "-executionpolicy bypass -File ${script}",
    enabled   => true,
    trigger   => [{
      schedule         => 'daily',
      start_time       => '00:00',
      #minutes_interval => 120,
      minutes_interval => 5,
      #minutes_duration => 1440, # 24 hours = repeat every 2 hours all day
    }],
    user      => 'SYSTEM',
  }
}
