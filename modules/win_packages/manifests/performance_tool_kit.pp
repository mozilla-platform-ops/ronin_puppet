# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::performance_tool_kit (
    String $moz_profile_source,
    String $moz_profile_file,
){

    if $::operatingsystem == 'Windows' {
        win_packages::win_msi_pkg  { 'WPTx64':
            pkg             => 'WPTx64-x86_en-us.msi',
            install_options => ['/quiet'],
        }
        file { $moz_profile_file:
            content   => $moz_profile_source,
            subscribe => Package['WPTx64'],
        }
        exec { 'install_moz_profile':
            command     => "${facts[custom_win_system32]}\\wbem\\mofcomp.exe ${moz_profile_file}",
            subscribe   => File[$moz_profile_file],
            refreshonly => true,
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}
