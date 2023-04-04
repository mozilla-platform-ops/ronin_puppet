class win_os_settings::no_sleep {

    $power_key    = "HKLM\\SYSTEM\\CurrentControlSet\\Control\\Power"
    $modern_sleep = "${power_key}\\ModernSleep"

    registry::value { 'HibernateEnabled' :
        key  => $power_key,
        type => dword,
        data => '0',
    }
    registry::value { "${modern_sleep}\\EnableAction":
        ensure => absent
    }
}
