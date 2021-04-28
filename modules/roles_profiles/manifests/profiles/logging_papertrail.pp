# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::logging_papertrail (
    String $papertrail_host,
    Integer $papertrail_port,
    Array   $systemd_units = [],  # optional, only show these units
    Array   $syslog_identifiers = [],  # optional, display these syslog identifiers also
) {
    case $::operatingsystem {
        'Ubuntu': {
            # TODO: check release/version

            class { 'linux_papertrail':
                papertrail_host    => $papertrail_host,
                papertrail_port    => $papertrail_port,
                systemd_units      => $systemd_units,  # optional, only show these units
                syslog_identifiers => $syslog_identifiers,  # optional, display these syslog identifiers also
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
