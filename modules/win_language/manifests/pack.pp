# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define win_language::pack (
  String $pack
) {

    $install_script = "${pack}-pack.install.ps1"
    $script_path    = "${facts['custom_win_roninprogramdata']}\\${install_script}"

    file { $script_path:
        content => epp('win_language/install_language_pack.ps1.epp'),
    }
    exec { 'install_pack':
        provider => powershell,
        command  => $script_path,
    }
}
