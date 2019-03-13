# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::roles::mojave_taskcluster_worker {

    include ::roles_profiles::profiles::timezone
    include ::roles_profiles::profiles::homebrew
    include ::roles_profiles::profiles::ntp
    include ::roles_profiles::profiles::network
    include ::roles_profiles::profiles::disable_services
    include ::roles_profiles::profiles::talos
}
