class win_disable_services::disable_real_time_protection {

    $win_defend_key = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows Defender"

    registry::value { 'DisableRealtimeMonitoring' :
        key  => "${win_defend_key}\\Real-Time Protection",
        type => dword,
        data => '1',
    }
    ## Disable Cloud Delivery
    registry::value { 'SpynetReporting' :
        key  => "${win_defend_key}\\Spynet",
        type => dword,
        data => '0',
    }
    ## Disable Sample submission
    registry::value { 'SubmitSamplesConsent' :
        key  => "${win_defend_key}\\Spynet",
        type => dword,
        data => '0',
    }
    ## Disable TamperProtection
    registry::value { 'TamperProtection' :
        key  => "${win_defend_key}\\Features",
        type => dword,
        data => '0',
    }
}
