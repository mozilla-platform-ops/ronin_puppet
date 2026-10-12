# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::macos_tcc_perms {

    class { 'macos_tcc_perms':
                enabled => true,
            }

    # Detection only, for the ScreenCapture grant macos_tcc_perms cannot supply on
    # a SIP-on host: its system-database write needs SIP off, and the user-database
    # fallback it takes instead is never read by TCC for this service. Obtaining
    # the grant is a provisioning-path concern (relops-bootstrap); this just makes
    # a host that lacks it visible instead of silently failing every screen
    # capture. See bug 2073303.
    class { 'macos_screencapture_check':
                enabled => true,
            }
}
