# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class fw::roles::log_aggregator {

    case $::fqdn {
        /.*\.mdc1\.mozilla\.com/: {
            include ::fw::profiles::ssh_from_rejh_logging
            include ::fw::profiles::nrpe_from_nagios
            include ::fw::profiles::syslog_from_mdc1_releng
            include ::fw::profiles::syslog_from_mtv2_qa
        }
        /.*\.mdc2\.mozilla\.com/: {
            include ::fw::profiles::ssh_from_rejh_logging
            include ::fw::profiles::nrpe_from_nagios
            include ::fw::profiles::syslog_from_mdc2_releng
            include ::fw::profiles::syslog_from_mtv2_qa
        }
        default:{
            # Silently skip other DCs
        }
    }
}
