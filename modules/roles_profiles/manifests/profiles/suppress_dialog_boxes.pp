# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::suppress_dialog_boxes {

    case $::operatingsystem {
        'Darwin': {
            # Disables the setup assistant application that runs after a fresh OS installation
            # Installs a payloadless package which suppresses the Setup Assistant the first time the OS starts
            # Credit to: https://github.com/MagerValp/SkipAppleSetupAssistant
            include packages::skip_apple_setup_assistant

            # These profiles suppress the dialog boxes when a new user logs in for the first time
            include macos_mobileconfig_profiles::skipdataandprivacy
            include macos_mobileconfig_profiles::skipicloudsetup

            # Suppress the bluetooth keyboard/mouse setup dialog boxes that appear when there is no keyboard and/or mouse connected
            include macos_utils::disable_bluetooth_setup

            # Suppress Diagnostic Submissions
            include macos_mobileconfig_profiles::disable_diagnostic_submissions
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
