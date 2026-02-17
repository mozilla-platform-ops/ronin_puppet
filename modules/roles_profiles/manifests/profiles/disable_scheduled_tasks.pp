class win_disable_services::disable_scheduled_tasks {
  exec { 'disable_scheduled_tasks':
    command  => file('win_disable_services/scheduled_tasks/disable.ps1'),
    provider => powershell,
    timeout  => 300,
  }
}
