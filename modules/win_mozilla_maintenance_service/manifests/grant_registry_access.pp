# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_maintenance_service::grant_registry_access {

require win_mozilla_maintenance_service::install

    file { "${facts[custom_win_roninprogramdata]}\\mozilla_serivce_reg_permisions.txt":
        content => "${win_mozilla_maintenance_service::maintenance_key} [7]",
    }
    exec { 'open_permisions_registry_key':
        command     =>
            "${facts[custom_win_system32]}\\regini.exe ${facts[custom_win_roninprogramdata]}\\mozilla_serivce_reg_permisions.txt",
        subscribe   => File["${facts[custom_win_roninprogramdata]}\\mozilla_serivce_reg_permisions.txt"],
        refreshonly => true,
    }
}
