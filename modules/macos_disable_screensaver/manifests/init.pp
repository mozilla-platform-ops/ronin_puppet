# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Disables the macOS screen saver and removes the password-after-screensaver
# requirement by writing to the system-level com.apple.screensaver preferences
# domain as root.  Writing to /Library/Preferences sets a system-wide default
# that applies to all users, replacing the MDM/mobileconfig profile approach.
# Works on macOS 10.15 and later.
class macos_disable_screensaver {
  $domain = '/Library/Preferences/com.apple.screensaver'

  macos_utils::defaults { 'screensaver_idleTime':
    domain   => $domain,
    key      => 'idleTime',
    value    => '0',
    val_type => 'int',
  }

  macos_utils::defaults { 'screensaver_loginWindowIdleTime':
    domain   => $domain,
    key      => 'loginWindowIdleTime',
    value    => '0',
    val_type => 'int',
  }

  macos_utils::defaults { 'screensaver_askForPassword':
    domain   => $domain,
    key      => 'askForPassword',
    value    => '0',
    val_type => 'bool',
  }

  macos_utils::defaults { 'screensaver_askForPasswordDelay':
    domain   => $domain,
    key      => 'askForPasswordDelay',
    value    => '0',
    val_type => 'int',
  }
}
