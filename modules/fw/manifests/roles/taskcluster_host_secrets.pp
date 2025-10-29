# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class fw::roles::taskcluster_host_secrets {

    case $facts['networking']['fqdn'] {
        /.*\.(mdc1|mdc2)\.mozilla\.com/: {
            include ::fw::profiles::taskcluster_host_secrets_from_dc_test
            include ::fw::profiles::ssh_from_rejh_logging
            include ::fw::profiles::nrpe_from_nagios
        }
        default:{
            # Silently skip other DCs
        }
    }
}
