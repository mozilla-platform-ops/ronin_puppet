class win_os_settings::no_sleep {

    $power_key = "HKLM\\SYSTEM\\CurrentControlSet\\Control\\Power"
    $pwr_setting = "PowerSettings\\238C9FA8-0AAD-41ED-83F4-97BE242C8F20\\7bc4a2f9-d8fc-4469-b07b-33eb785aaca0"
    $ultimate_scheme_key  = "DefaultPowerSchemeValues\\e9a42b02-d5df-448d-aa00-03f14749eb61"

    registry::value { 'HibernateEnabled' :
        key  => $power_key,
        type => dword,
        data => '0',
    }

    ## Only sets for Ultimate Performance scheme
    registry_key { $ultimate_scheme_key:
        ensure => present,
    }
    registry::value { 'DCSettingIndex' :
        key  => $ultimate_scheme_key,
        type => dword,
        data => '0',
    }
}
