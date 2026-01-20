# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_nsclient::init (
    String $server,
    String $server_pw
){

    win_packages::win_msi_pkg  { 'NSClient++ (x64)':
        pkg             => 'NSCP-0.9.15-x64.msi',
        install_options => ['/quiet'],
    }
    file { "${facts['custom_win_programfiles']}\\NSClient++\\nsclient.ini":
        content   => epp('win_nsclient/nsclient.ini.epp'),
        show_diff => false,
    }
    file { "${facts['custom_win_programfiles']}\\NSClient++\\scripts\\screen_res.ps1":
        content => file('win_nsclient/screen_res.ps1'),
    }
    service { 'nsclient++':
        ensure => running,
        enable => true,
    }
}
