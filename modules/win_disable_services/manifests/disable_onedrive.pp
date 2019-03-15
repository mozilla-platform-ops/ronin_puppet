# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_onedrive {

    # This script will disable and remove all portions of onedrive
    # and prevent onedrive from being setup on future user creation
    # Using puppetlabs-powershell
    # Script & modules are originally from https://github.com/W4RH4WK/Debloat-Windows-10

    $module_dir = "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0\\modules"

    file { "${module_dir}\\force-take-own":
        ensure => directory,
    }
    file { "${module_dir}\\force-mkdir":
        ensure => directory,
    }

    file { "${module_dir}\\force-mkdir\\force-mkdir.psm1":
        content => file('win_disable_services/force-mkdir.psm1'),
    }
    file { "${module_dir}\\take-own\\take-own.psm1":
        content => file('win_disable_services/take-own.psm1'),
        require => File["${module_dir}\\force-mkdir.psm1"],
    }


    exec { 'disable_onedrive':
        command  => file('win_disable_services/disable_onedrive.ps1'),
        provider => powershell,
        require  => File["${module_dir}\\take-own\\take-own.psm1"],
        onlyif   => 'Test-Path "$env:systemroot\SysWOW64\OneDriveSetup.exe"',
    }
}
# Bug list
# TODO port script into this manifest
# https://bugzilla.mozilla.org/show_bug.cgi?id=1535228
