# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_windows_defender {

    $script_dir = "${facts['custom_win_roninprogramdata']}\\disable_win_defend"

    file { $script_dir:
        ensure => directory,
    }
    file { "${script_dir}\\OwnRegistryKeys.bat":
        ensure  => present,
        content => file['win_disable_services/OwnRegistryKeys.bat'],
    }
    file { "${script_dir}\\OwnRegistryKeys.ps1":
        ensure  => present,
        content => file['win_disable_services/OwnRegistryKeys.ps1'],
    }
    file { "${script_dir}\\DisableWindowsDefender.bat":
        ensure  => present,
        content => file['win_disable_services/DisableWindowsDefender.bat'],
    }
    file { "${script_dir}\\DisableWindowsDefenderfeatures.reg":
        ensure  => present,
        content => file['win_disable_services/DisableWindowsDefenderfeatures.reg'],
    }
    file { "${script_dir}\\DisableWindowsDefenderobjects.reg":
        ensure  => present,
        content => file['win_disable_services/DisableWindowsDefenderobjects.reg'],
    }
    file { "${script_dir}\\DisableWindowsDefenderservices.reg":
        ensure  => present,
        content => file['win_disable_services/DisableWindowsDefenderservices.reg'],
    }
}
