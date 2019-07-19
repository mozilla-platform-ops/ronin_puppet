# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_firewall::disable_firewall {

    exec { 'windows_firewall':
        command => 'C:\Windows\System32\netsh.exe advfirewall set allprofiles state off'
    }
}
