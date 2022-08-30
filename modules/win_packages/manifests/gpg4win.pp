# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::gpg4win {

    if $facts['os']['name'] == 'Windows' {
        win_packages::win_exe_pkg  { 'gpg4win-2.3.0':
            pkg                    => 'gpg4win-2.3.0.exe',
            install_options_string => '/S',
            creates                => "${facts['custom_win_programfilesx86']}\\GNU\\GnuPG\\bin\\kleopatra.exe",
        }
    } else {
        fail("${module_name} does not support ${$facts['os']['name']}")
    }
}
