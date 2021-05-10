# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_windows_update {

    if $::operatingsystem == 'Windows' {

        $win_update_key    = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate"
        $win_update_au_key = "${win_update_key}\\AU"
        $win_au_key        = "HKLM\\SOFTWARE\\Microsoft\\Windows\\Windows\\AU"

        win_disable_services::disable_service { 'wuauserv':
        }

        # Using puppetlabs-registry
        registry_value { 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching\SearchOrderConfig':
            type => dword,
            data => '0',
        }
        registry_key { $win_au_key:
            ensure => present,
        }
        registry_value { "${win_au_key}\\AUOptions":
            type => dword,
            data => '1',
        }
        registry_value { "${win_au_key}\\NoAutoUpdate":
            type => dword,
            data => '1',
        }

        if $facts['custom_win_release_id'] == '1903' or '2004'{
            registry_value { "${win_update_au_key}\\NoAutoUpdate":
                type => dword,
                data => '1',
            }
            registry_value { "${win_update_au_key}\\AUOptions":
                type => dword,
                data => '2',
            }

            registry_value { "${win_update_key}\\DeferUpgrade":
                type => dword,
                data => '1',
            }
            registry_value { "${win_update_key}\\DeferUpgradePeriod":
                type => dword,
                data => '8',
            }
            registry_value { "${win_update_key}\\DeferUpdatePeriod":
                type => dword,
                data => '4',
            }

            registry_value { "${win_update_au_key}\\NoAutoRebootWithLoggedOnUsers":
                type => dword,
                data => '1',
            }
            registry_value { "${win_update_au_key}\\ScheduledInstallDay":
                type => dword,
                data => '1',
            }
            registry_value { "${win_update_au_key}\\ScheduledInstallTime":
                type => dword,
                data => '1',
            }
            registry_value { "${win_update_au_key}\\AutomaticMaintenanceEnabled":
                type => dword,
                data => '0',
            }
            registry_value { "${win_update_au_key}\\MaintenanceDisabled":
                type => dword,
                data => '1',
            }
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
    # Bug List
    # https://bugzilla.mozilla.org/show_bug.cgi?id=>1510756
    # https://bugzilla.mozilla.org/show_bug.cgi?id=>1485628
}
