# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_scheduled_tasks::kill_local_clipboard {
  $kill_localclip = "${facts['custom_win_roninprogramdata']}\\kill_local_clipboard.ps1"

  if $facts['os']['name'] == 'Windows' {
    file { $kill_localclip:
      content => file('win_scheduled_tasks/kill_local_clipboard.ps1'),
    }
    # Resource from puppetlabs-scheduled_task
    scheduled_task { 'kill_remote_clipboard':
      ensure    => 'present',
      command   => "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0\\powershell.exe",
      arguments => "-executionpolicy bypass -File ${kill_localclip}",
      enabled   => true,
      trigger   => [{
          'schedule'         => 'boot',
          'minutes_interval' => '0',
          'minutes_duration' => '0'
      }],
      user      => 'system',
    }
  } else {
    fail("${module_name} does not support ${facts['os']['name']}")
  }
}
