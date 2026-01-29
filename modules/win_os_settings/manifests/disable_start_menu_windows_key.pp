# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_os_settings::disable_start_menu_windows_key {

  registry::value { 'DisableWindowsKeyScancodeMap' :
    key  => 'HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout',
    name => 'Scancode Map',
    type => binary,
    data => '00 00 00 00 00 00 00 00 03 00 00 00 00 00 5B E0 00 00 5C E0 00 00 00 00',
  }
}
