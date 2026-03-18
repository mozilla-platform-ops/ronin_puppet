# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_bios::nuc13 (
    String $script_dir,
    String $bios_src,
    String $isetup_src,
    String $bios_cfg,
) {

    require win_maintenance::maintenance_script_dir

    archive { $bios_cfg:
        ensure  => present,
        source  => "${bios_src}/${bios_cfg}",
        path    => "${script_dir}\\${bios_cfg}",
        creates => "${script_dir}\\${bios_cfg}",
        cleanup => false,
        extract => false,
        notify  => Exec['nuc13_bios_apply'],
    }

    archive { 'amigendrv64.sys':
        ensure  => present,
        source  => "${isetup_src}/amigendrv64.sys",
        path    => "${script_dir}\\amigendrv64.sys",
        creates => "${script_dir}\\amigendrv64.sys",
        cleanup => false,
        extract => false,
    }

    archive { 'iSetupCfgWin64.exe':
        ensure  => present,
        source  => "${isetup_src}/iSetupCfgWin64.exe",
        path    => "${script_dir}\\iSetupCfgWin64.exe",
        creates => "${script_dir}\\iSetupCfgWin64.exe",
        cleanup => false,
        extract => false,
    }

    exec { 'nuc13_bios_apply':
        command     => "${script_dir}\\iSetupCfgWin64.exe /o /s ${bios_cfg}",
        cwd         => $script_dir,
        refreshonly => true,
        require     => [
            Archive['amigendrv64.sys'],
            Archive['iSetupCfgWin64.exe'],
        ],
    }
}
