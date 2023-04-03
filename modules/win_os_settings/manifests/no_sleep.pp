class win_os_settings::no_sleep {

    $power_key = "HKLM\\\SYSTEM\\CurrentControlSet\\Control\\Power"

    registry::value { 'PlatformAoAcOverride' :
        key  => $power_key,
        type => dword,
        data => '0',
    }
}
