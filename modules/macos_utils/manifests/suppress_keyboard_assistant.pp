# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_utils::suppress_keyboard_assistant {
  exec { 'suppress_keyboard_assistant':
    command => '/usr/bin/defaults write /Library/Preferences/com.apple.keyboardtype keyboardtype -dict "4101-5341-33" -int 40',
    unless  => '/usr/bin/defaults read /Library/Preferences/com.apple.keyboardtype keyboardtype 2>/dev/null | /usr/bin/grep -q "4101-5341-33"',
    user    => 'root',
  }
}
