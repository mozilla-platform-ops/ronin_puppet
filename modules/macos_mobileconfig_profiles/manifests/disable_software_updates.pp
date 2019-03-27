# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_mobileconfig_profiles::disable_software_updates {

    mac_profiles_handler::manage { 'com.github.erikberglund.ProfileCreator.7AF6CC8C-EA10-4CD9-B145-77FD3CCFEF35':
        ensure      => 'present',
        file_source => 'puppet:///modules/macos_mobileconfig_profiles/org.mozilla.disable_software_updates.mobileconfig',
    }
}
