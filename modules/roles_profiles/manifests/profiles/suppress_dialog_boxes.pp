# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::suppress_dialog_boxes {
  case $facts['os']['name'] {
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
    'Windows': {
      include win_os_settings::disable_notifications

      # Bug list
      # https://bugzilla.mozilla.org/show_bug.cgi?id=1562024
      # https://bugzilla.mozilla.org/show_bug.cgi?id=1373551
      # https://bugzilla.mozilla.org/show_bug.cgi?id=1397201#c58"
    }
    default: {
      fail("${$facts['os']['name']} not supported")
    }
  }
}
