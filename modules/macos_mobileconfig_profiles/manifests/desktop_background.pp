# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_mobileconfig_profiles::desktop_background {

    mac_profiles_handler::manage { 'com.github.erikberglund.ProfileCreator.CB0ADD7C-78DE-4C29-854B-3FC332E953A6':
        ensure      => 'present',
        file_source => 'puppet:///modules/macos_mobileconfig_profiles/org.mozilla.desktop_background.mobileconfig',
    }
}
