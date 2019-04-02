# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_utils::show_scroll_bars {

    macos_utils::defaults { 'show_scroll_bars':
            domain   => '/Library/Preferences/.GlobalPreferences.plist',
            key      => 'AppleShowScrollBars',
            value    => 'Always',
            val_type => 'string',
    }
}
