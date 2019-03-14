# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_os_settings::powershell_profile {

    $powershell_dir = "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0"

    file { "${powershell_dir}\\Microsoft.PowerShell_profile.ps1":
        content => file('win_os_settings/Microsoft.PowerShell_profile.ps1'),
    }
}

# Bug list
