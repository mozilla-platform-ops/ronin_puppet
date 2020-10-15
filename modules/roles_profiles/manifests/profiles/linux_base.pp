# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::linux_base {

    case $::operatingsystem {
        'Ubuntu': {
            include ::roles_profiles::profiles::locale
            include ::roles_profiles::profiles::timezone
            include ::roles_profiles::profiles::ntp
            include ::roles_profiles::profiles::motd
            include ::roles_profiles::profiles::users
            include ::roles_profiles::profiles::relops_users
            include ::roles_profiles::profiles::sudo

            include linux_packages::mercurial

            include disable_services

            # TODO:
            # - add auditd
            # - add sending of logs to log aggregator/relay
            # - repo pinning
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
