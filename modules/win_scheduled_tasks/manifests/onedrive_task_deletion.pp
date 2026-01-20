class win_scheduled_tasks::onedrive_task_deletion {
  $onedrive_task_deletion_ps = "${facts['custom_win_roninprogramdata']}\\onedrive_task_deletion.ps1"

  if $facts['os']['name'] == 'Windows' {

    file { $onedrive_task_deletion_ps:
      ensure  => file,
      content => file('win_scheduled_tasks/onedrive_task_deletion.ps1'),
    }

    scheduled_task { 'one_drive_task_deletion':
      ensure    => present,
      command   => "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0\\powershell.exe",
      arguments => "-executionpolicy bypass -File \"${onedrive_task_deletion_ps}\"",
      enabled   => true,
      trigger   => [{
        schedule => boot,
      }],
      user      => 'SYSTEM',
      require   => File[$onedrive_task_deletion_ps],
    }

  } else {
    fail("${module_name} does not support ${facts['os']['name']}")
  }
}
