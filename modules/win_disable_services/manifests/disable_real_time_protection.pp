class win_disable_services::disable_real_time_protection {

    $win_defend_key = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows Defender"
    $sys_service_key = "HKLM:\\SYSTEM\CurrentControlSet\\Services"


    registry_value { "${sys_service_key}\\Sense\\start" :
        ensure => present,
        type   => dword,
        data   => '4',
    }
    exec { 'disable_realtime':
        command  => 'Set-MpPreference -DisableRealtimeMonitoring $true',
        provider => powershell,
    }

    ## Disable Cloud Delivery
    registry::value { 'SpynetReporting' :
        key  => "${win_defend_key}//Spynet",
        type => dword,
        data => '0',
    }
    ## Disable Sample submission
    registry::value { 'SubmitSamplesConsent' :
        key  => "${win_defend_key}//Spynet",
        type => dword,
        data => '0',
    }
}
