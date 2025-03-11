# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_os_settings::intel_gfx_settings {

    exec { 'disable_generic_adapter':
        command  => file('win_os_settings/disable_generic_adapter.ps1'),
        provider => 'powershell',
    }
}
