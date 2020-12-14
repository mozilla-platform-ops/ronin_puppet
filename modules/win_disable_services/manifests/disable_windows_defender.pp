# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_windows_defender {

    if $::operatingsystem == 'Windows' {

        $win_defend_key       = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows Defender"
        $real_time_key        = "${win_defend_key}\\Real-Time Protection"
        $services_key         = "HKLM\\SYSTEM\\CurrentControlSet\\Services"
        $acl_services_key     = "hklm:SYSTEM\\CurrentControlSet\\Services"
        $diabled_start_value  = [
                                "${services_key}\\wscsvc\\start",
                                "${services_key}\\SecurityHealthService\\start",
                                "${services_key}\\Sense\\start",
                                "${services_key}\\WdBoot\\start",
                                "${services_key}\\WdFilter\\start",
                                "${services_key}\\WdNisDrv\\start",
                                "${services_key}\\WdNisSvc\\start",
                                "${services_key}\\WinDefend\\start"
                                ]
        $acl_reg_values       = [
                                "${acl_services_key}\\wscsvc\\start",
                                "${acl_services_key}\\SecurityHealthService\\start",
                                "${acl_services_key}\\Sense\\start",
                                "${acl_services_key}\\WdBoot\\start",
                                "${acl_services_key}\\WdFilter\\start",
                                "${acl_services_key}\\WdNisDrv\\start",
                                "${acl_services_key}\\WdNisSvc\\start",
                                "${acl_services_key}\\WinDefend\\start"
                                ]

        # This will prevent the service from starting on next boot.
        # see below bug
        # Using puppetlabs-registry
        registry::value { 'DisableConfig' :
            key  => $win_defend_key,
            type => dword,
            data => '1',
        }
        registry::value { 'DisableAntiSpyware' :
            key  => $win_defend_key,
            type => dword,
            data => '1',
        }
        if $facts['custom_win_release_id'] == '1903' {
            registry::value { 'DisableRealtimeMonitoring' :
                key  => $win_defend_key,
                type => dword,
                data => '1',
            }
            registry::value { 'DisableBehaviorMonitoring' :
                key  => $real_time_key,
                type => dword,
                data => '1',
            }
      registry::value { 'DisableOnAccessProtection' :
        key  => $real_time_key,
        type => dword,
        data => '1',
      }
      registry::value { 'DisableOnAccessProtection' :
        key  => $real_time_key,
        type => dword,
        data => '1',
      }
    }
        # Windows defender supporting services
        # This will fail on first run and will need a reboot
        # SecurityHealthService and sense actively watch the registry values of the other services,
        # and there start registry value needs to be changed and then the node needs rebooted
        # Also note this will fail on Windows 7
        registry_value { $diabled_start_value:
            ensure => present,
            type   => dword,
            data   => '4',
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
# Bug List
# https://bugzilla.mozilla.org/show_bug.cgi?id=1512435
# https://bugzilla.mozilla.org/show_bug.cgi?id=1509722
