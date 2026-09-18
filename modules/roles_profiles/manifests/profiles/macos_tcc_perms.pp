# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::macos_tcc_perms {

    class { 'macos_tcc_perms':
                enabled => true,
            }

    # Companion for the ScreenCapture grant on SIP-enabled hosts, which
    # macos_tcc_perms cannot supply: its system-database write needs SIP off,
    # and the user-database fallback it takes instead is never read by TCC for
    # this service. Self-gating -- a no-op where SIP is off. See bug 2073303.
    class { 'macos_screencapture_grant':
                enabled => true,
            }
}
