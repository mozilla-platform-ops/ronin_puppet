scheduled_task { 'Run Notepad':
  ensure   => absent,
  provider => 'taskscheduler_api2'
}
