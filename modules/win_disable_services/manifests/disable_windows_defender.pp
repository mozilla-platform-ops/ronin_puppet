# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_windows_defender {

    if $::operatingsystem == 'Windows' {

        $win_defend_key       = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows Defender"
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

        # Windows defender supporting services
        # In order to change key ownership must be change to administrator SID:S-1-5-32-544
        # This shoukd catch any combination that may be needed on various platforms
        registry_key { $diabled_start_value:
            ensure => present,
        }
#        reg_acl { $acl_reg_values:
#            owner       => $facts['custom_win_admin_sid'],
#            permissions =>
#                [
#                    {'RegistryRights' => 'FullControl', 'IdentityReference' => 'BUILTIN\Administrators' },
#                    {'RegistryRights' => 'FullControl', 'IdentityReference' => $facts['custom_win_admin_sid']},
#                ],
#            require     => Registry_key[$diabled_start_value],
#       }
        registry_value { $diabled_start_value:
            ensure => present,
            type   => dword,
            data   => '4',
#          require => Reg_acl[$acl_reg_values]
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
# Bug List
# https://bugzilla.mozilla.org/show_bug.cgi?id=1512435
# https://bugzilla.mozilla.org/show_bug.cgi?id=1509722
