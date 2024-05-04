class win_disable_services::disable_real_time_protection {

    $win_defend_policy_key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender'
    $win_defend_key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender'
    #$win_defend_key = 'HKLM\SOFTWARE\Microsoft\Windows Defender'

#    registry_key { $win_defend_policy_key:
#        ensure => present,
#    }
    registry_key { $win_defend_key:
        ensure => present,
    }
    registry_value { "${win_defend_key}\\DisableRealtimeMonitoring" :
        #key  => "${win_defend_key}\\Real-Time Protection",
        ensure => present,
        type   => dword,
        data   => '1',
    }
    ## Disable Cloud Delivery
    registry::value { 'SpynetReporting' :
        key  => "${win_defend_policy_key}\\Spynet",
        type => dword,
        data => '0',
    }
    ## Disable Sample submission
    registry::value { 'SubmitSamplesConsent' :
        key  => "${win_defend_policy_key}\\Spynet",
        type => dword,
        data => '0',
    }
    ## Disable TamperProtection
    registry_value { "${win_defend_key}\\TamperProtection" :
        #key  => "${win_defend_key}\\Features",
        ensure => present,
        type   => dword,
        data   => '0',
    }
}
