scheduled_task { 'Run Notepad':
  ensure   => present,
  command  => 'C:\Windows\System32\notepad.exe',
  trigger  => {
    schedule   => daily,
    start_time => '12:00',
  },
  provider => 'taskscheduler_api2'
}
