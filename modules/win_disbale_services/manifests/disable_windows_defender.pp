# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disbale_services::disable_windows_defender {

    win_disbale_services::disable_service { 'WinDefend':
    }
    registry::value { 'DisableConfig' :
        key  => 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender',
        type => dword,
        data => '1',
    }
    registry::value { 'DisableAntiSpyware' :
        key  => 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender',
        type => dword,
        data => '1',
    }
}
# Bug List
# https://bugzilla.mozilla.org/show_bug.cgi?id=1512435
