class win_os_settings::no_sleep {

    $power_key    = "HKLM\\SYSTEM\\CurrentControlSet\\Control\\Power"
    $modern_sleep = "${power_key}\\ModernSleep"

    registry::value { 'HibernateEnabled' :
        key  => $power_key,
        type => dword,
        data => '0',
    }
    ## TODO: Add a check to prevent unnessary runs
    exec { 'disable_standby':
        command  => 'powercfg.exe -x -standby-timeout-ac 0',
        provider => powershell,
    }
    exec { 'disable_monitor_timeout':
        command  => 'powercfg.exe -x -monitor-timeout-ac 0',
        provider => powershell,
    }
}
