# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_utils::disable_setup_assistant {

    # Installs a payloadless package which suppresses the Setup Assistant the first time the OS starts
    # Created to: https://github.com/MagerValp/SkipAppleSetupAssistant

    file { '/private/tmp/SkipAppleSetupAssistant-1.0.pkg':
        source => 'puppet:///modules/macos_utils/SkipAppleSetupAssistant-1.0.pkg'
    }

    package { 'SkipAppleSetupAssistant-1.0':
        source   => '/private/tmp/SkipAppleSetupAssistant-1.0.pkg',
        provider => 'pkgdmg',
        require  => File['/private/tmp/SkipAppleSetupAssistant-1.0.pkg'],
    }
}
