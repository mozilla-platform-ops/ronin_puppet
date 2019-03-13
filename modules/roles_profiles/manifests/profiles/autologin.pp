# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::autologin {

    case $::operatingsystem {
        'Darwin': {
            # Disables the setup assistant application that runs after a fresh OS installation
            include macos_utils::disable_setup_assistant
            # These profiles suppress the dialog boxes when a new user logs in for the first time
            include macos_mobileconfig_profiles::skipdataandprivacy
            include macos_mobileconfig_profiles::skipicloudsetup
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
