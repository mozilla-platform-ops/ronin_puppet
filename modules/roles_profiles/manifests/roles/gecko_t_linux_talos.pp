# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::roles::gecko_t_linux_talos {

    include ::roles_profiles::profiles::linux_base

    # linux build/test worker stuff
    include ::roles_profiles::profiles::cltbld_user
    include ::roles_profiles::profiles::vnc
    include ::roles_profiles::profiles::gui
    include ::roles_profiles::profiles::google_chrome

    # nrpe and checks
    #   TODO: required or are we migrating to influx?

    #include ::fw::roles::linux_taskcluster_worker

    # talos stuff
    case $::operatingsystemrelease {
        '18.04': {
          include ::roles_profiles::profiles::gecko_t_linux_talos_generic_worker
        }
        '22.04': {
          include ::roles_profiles::profiles::gecko_t_linux_2204_talos_generic_worker
        }
        default: {
          fail("Ubuntu ${::operatingsystemrelease} is not supported")
        }
    }
}
