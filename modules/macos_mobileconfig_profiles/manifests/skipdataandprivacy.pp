# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_mobileconfig_profiles::skipdataandprivacy {

    mac_profiles_handler::manage { 'skipdataandprivacy':
        ensure      => 'present',
        file_source => file('macos_mobileconfig_profiles/skipdataandprivacy.mobileconfig'),
        type        => 'template',
    }
}
