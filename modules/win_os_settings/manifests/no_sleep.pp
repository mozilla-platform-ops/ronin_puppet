class win_os_settings::no_sleep {

    $power_key = "HKLM\\SYSTEM\\CurrentControlSet\\Control\\Power"

    registry::value { 'HibernateEnabled' :
        key  => $power_key,
        type => dword,
        data => '0',
    }
    registry::value { 'PlatformAoAcOverride' :
        key  => $power_key,
        type => dword,
        data => '0',
    }
    registry::value { 'CsEnabled' :
        key  => $power_key,
        type => dword,
        data => '0',
    }
}
