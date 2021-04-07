# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::logging_papertrail (
    String $papertrail_host,
    Integer $papertrail_port,
) {
    case $::operatingsystem {
        'Ubuntu': {
            # TODO: check release/version

            class { 'linux_papertrail':
                papertrail_host => $papertrail_host,
                papertrail_port => $papertrail_port,
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
