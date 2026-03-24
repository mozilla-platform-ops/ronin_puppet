# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::nuc_management {

    case $facts['os']['name'] {
        'Windows': {
            if ($facts['custom_win_location'] == 'datacenter') {
                #$script_dir = "${facts['custom_win_roninprogramdata']}\\scripts"
                $script_dir = "${facts['custom_win_systemdrive']}\\\\management_scripts"

                class { 'win_maintenance::maintenance_script_dir':
                    script_dir => $script_dir,
                }
                class { 'win_maintenance::force_pxe_install':
                    script_dir => $script_dir,
                }
                class { 'win_maintenance::pool_audit':
                    script_dir => $script_dir,
                }
                class { 'win_maintenance::fleetroll_mvp_collect':
                    script_dir => $script_dir,
                }
            } else {
                warning("workers associated with ${facts['custom_win_location']} location are not supported")
            }
        }
        default: {
            fail("${facts['os']['name']} not supported")
        }
    }
}
