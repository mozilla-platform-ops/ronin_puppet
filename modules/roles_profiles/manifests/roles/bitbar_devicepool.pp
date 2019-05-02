# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::roles::bitbar_devicepool {

    include ::roles_profiles::profiles::relops_users
    include ::roles_profiles::profiles::cia_users
    include ::roles_profiles::profiles::sudo
    include ::roles_profiles::profiles::bitbar_devicepool
    include ::roles_profiles::profiles::remove_bootstrap_user
}
