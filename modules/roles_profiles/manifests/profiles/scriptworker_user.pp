# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::scriptworker_user {
    case $::hostname {
        /^dep-mac-v3-signing\d+/: {
            class { 'signing_worker::system_user':
                user => 'depbld1',
            }
            class { 'signing_worker::system_user':
                user => 'depbld2',
            }
            class { 'signing_worker::system_user':
                user => 'tbbld',
            }
        }
        default: {
            class { 'signing_worker::system_user':
                user => 'cltbld',
            }
        }
    }
}
