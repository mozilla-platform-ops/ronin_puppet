# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_utils::disable_bluetooth_setup {

    macos_utils::defaults { 'BluetoothAutoSeekKeyboard':
        domain   => '/Library/Preferences/com.apple.Bluetooth',
        key      => 'BluetoothAutoSeekKeyboard',
        value    => '0',
        val_type => 'int',
    }

    macos_utils::defaults { 'BluetoothAutoSeekPointingDevice':
        domain   => '/Library/Preferences/com.apple.Bluetooth',
        key      => 'BluetoothAutoSeekPointingDevice',
        value    => '0',
        val_type => 'int',
    }
}
