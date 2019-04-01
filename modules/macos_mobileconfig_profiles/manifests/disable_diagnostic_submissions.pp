# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_mobileconfig_profiles::disable_diagnostic_submissions {

    mac_profiles_handler::manage { 'com.github.erikberglund.ProfileCreator.90485A56-F926-4DFA-9E3C-212DEDC3C13C':
        ensure      => 'present',
        file_source => 'puppet:///modules/macos_mobileconfig_profiles/org.mozilla.disable_diagnostic_submissions.mobileconfig',
    }
}
