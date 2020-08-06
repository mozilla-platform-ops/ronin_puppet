# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_maintenance_service::install (
    String $source_location
) {

    $local_exe = "{facts['custom_win_temp_dir']}\\maintenanceservice.exe"

    file { $local_exe:
        source => "${source_location}/maintenanceservice.exe",
    }
    win_packages::win_exe_pkg  { 'mozilla_maintenance_service':
        pkg                    => 'maintenanceservice_installer.exe',
        install_options_string =>  '/S',
        creates                => "${facts['custom_win_programfilesx86']}\\Mozilla Maintenance Service\\uninstall.exe.BAK",
        require                => File[$local_exe],

    }
}
