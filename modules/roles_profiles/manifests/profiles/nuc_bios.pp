# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::nuc_bios {
    case $facts['os']['name'] {
        'Windows': {
            if ($facts['custom_win_location'] == 'datacenter') {
                $script_dir = "${facts['custom_win_systemdrive']}\\management_scripts"
                $bios_src   = lookup('windows.bios.NUC13.bios_src')
                $isetup_src = lookup('windows.bios.NUC13.isetup_src')
                $bios_date  = lookup('windows.bios.NUC13.date')
                $bios_cfg   = "${bios_date}_nuc_bios.txt"

                # The BIOS config file is exported from a known good NUC using:
                #   iSetupCfgWin64.exe /e /s <filename>
                # The resulting .txt file can also be edited directly if you're feeling brave.

                class { 'win_bios::nuc13':
                    script_dir => $script_dir,
                    bios_src   => $bios_src,
                    isetup_src => $isetup_src,
                    bios_cfg   => $bios_cfg,
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
