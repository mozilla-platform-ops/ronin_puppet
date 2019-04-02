# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_mobileconfig_profiles::disable_gatekeeper {

    mac_profiles_handler::manage { 'com.github.erikberglund.ProfileCreator.DBF8AC5D-D27C-43D2-A7B9-5948CEE56BCF':
        ensure      => 'present',
        file_source => 'puppet:///modules/macos_mobileconfig_profiles/org.mozilla.disable_gatekeeper.mobileconfig',
    }
}
