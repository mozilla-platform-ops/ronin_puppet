# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_mobileconfig_profiles::power_management {

    mac_profiles_handler::manage { 'com.github.erikberglund.ProfileCreator.48712DE2-ADC7-41AF-BF12-6EB5C7B2829F':
        ensure      => 'present',
        file_source => 'puppet:///modules/macos_mobileconfig_profiles/org.mozilla.power_management.mobileconfig',
    }
}
