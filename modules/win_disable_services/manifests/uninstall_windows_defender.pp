# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::uninstall_windows_defender {

    exec { 'set_category':
        command  => file('win_disable_services/windows_defender/UninstallWinDefend.ps1'),
        provider => powershell,
    }
}
