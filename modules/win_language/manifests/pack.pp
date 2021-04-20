# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_language::pack (
  String $pack
) {

    $install_script = 'language_pack_install.ps1'
    $script_path    = "${facts['custom_win_roninprogramdata']}\\${install_script}"

    file { $script_path:
        content => file('win_language/install_language_pack.ps1'),
    }
    exec { "install_pack_${pack}":
        provider => powershell,
        command  => "${script_path} ${pack}",
    }
}
