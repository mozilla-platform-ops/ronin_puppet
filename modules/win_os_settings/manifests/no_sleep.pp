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

    # Bug 2026458: Prevent GUID_SESSION_DISPLAY_STATUS from sending
    # PowerMonitorOff on headless Azure GPU VMs (25H2 A10-8Q vGPU).
    # The VIDEOIDLE subgroup controls display idle timeout behavior.
    $power_settings_key = "${power_key}\\PowerSettings"
    $display_subgroup    = '7516b95f-f776-4464-8c53-06167f40cc99'
    $video_idle_setting  = '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e'
    $video_idle_key      = "${power_settings_key}\\${display_subgroup}\\${video_idle_setting}"

    # ACSettingIndex = 0 means "never turn off display" for the active
    # power scheme, applied via registry to persist across reboots.
    registry_value { "${video_idle_key}\\ACSettingIndex":
        ensure => present,
        type   => 'dword',
        data   => 0,
    }
}
