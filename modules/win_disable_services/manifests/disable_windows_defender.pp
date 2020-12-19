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
            registry::value { 'DisableAntivirus' :
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
        # and their start registry value needs to be changed and then the node needs rebooted
        # Also note this will fail on Windows 7
        #reg_acl { $acl_reg_values:
            #owner       => $facts['custom_win_admin_sid'],
            #permissions =>
                #[
                    #{'RegistryRights' => 'FullControl', 'IdentityReference' => 'BUILTIN\Administrators' },
                    #{'RegistryRights' => 'FullControl', 'IdentityReference' => $facts['custom_win_admin_sid']},
                    #{'InheritanceFlags' => 'ContainerInherit'},
                    #{'AccessControlType' => 'Allow'},
                #]
        #}
        win_shared::take_own_reg_key { 'windefend_service':
            regkey => "${services_key}\\WinDefend",
        }
        win_shared::take_own_reg_key { 'wscsvc_service':
            regkey => "${services_key}\\wscsvc",
        }
        win_shared::take_own_reg_key { 'securityhealthservice_service':
            regkey => "${services_key}\\SecurityHealthService",
        }
        win_shared::take_own_reg_key { 'sense_service':
            regkey => "${services_key}\\Sense",
        }
        win_shared::take_own_reg_key { 'wdboot_service':
            regkey => "${services_key}\\WdBoot",
        }
        win_shared::take_own_reg_key { 'wdfilter_service':
            regkey => "${services_key}\\WdFilter",
        }
        win_shared::take_own_reg_key { 'wdnisdrv_service':
            regkey => "${services_key}\\WdNisDrv",
        }
        win_shared::take_own_reg_key { 'wdnissvc_service':
            regkey => "${services_key}\\WdNisSvc",
        }
        registry_value { $diabled_start_value:
        #registry_value { "${services_key}\\WinDefend\\start":
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
