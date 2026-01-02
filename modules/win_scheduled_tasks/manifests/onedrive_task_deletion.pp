# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_scheduled_tasks::onedrive_task_deletion {
  $onedrive_task_deletion_ps = "${facts['custom_win_roninprogramdata']}\\onedrive_task_deletion.ps1"

  if $facts['os']['name'] == 'Windows' {
    file { $onedrive_task_deletion_ps:
      content => file('win_scheduled_tasks/onedrive_task_deletion.ps1'),
    }
    # Resource from puppetlabs-scheduled_task
    scheduled_task { 'one_drive_task_deletion':
      ensure    => 'present',
      command   => "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0\\powershell.exe",
      arguments => "-executionpolicy bypass -File ${onedrive_task_deletion_ps}",
      enabled   => true,
      trigger   => [{
          'schedule'         => 'boot',
          'minutes_interval' => '0',
          'minutes_duration' => '0'
      }],
      user      => 'system',
    }
  } else {
    fail("${module_name} does not support ${$facts['os']['name']}")
  }
}
