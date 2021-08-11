# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_os_settings::disbale_vm_clipboard {

  # Using puppetlabs-registry
    registry::value { 'DisableClipboardRedirection':
        key  => 'HKLM\Software\Microsoft\Terminal Server',
        type => dword,
        data => '1',
    }
}
