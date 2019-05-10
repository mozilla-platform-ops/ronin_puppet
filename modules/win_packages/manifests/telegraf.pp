# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::telegraf (
    String $telegraf_config_source,
){

    if $::operatingsystem == 'Windows' {

        $version = '1.10.3'
        $telegraf_config_file = "${facts['custom_win_systemdrive']}\\telegraf\\telegraf.conf"

        win_packages::win_zip_pkg { "telegraf-${version}":
            # https://dl.influxdata.com/telegraf/releases/telegraf-1.10.3_windows_amd64.zip
            pkg         => "telegraf-${version}.zip",
            creates     => "${facts['custom_win_systemdrive']}\\telegraf\\telegraf.exe",
            destination => "${facts['custom_win_systemdrive']}\\",
        }
        file { $telegraf_config_file:
            source      => $telegraf_config_source,
        }
        exec { 'install_telegraf_service':
            command     => "telegraf.exe -service install -config ${telegraf_config_file}",
            subscribe   => File[$telegraf_config_file],
            refreshonly => true,
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
