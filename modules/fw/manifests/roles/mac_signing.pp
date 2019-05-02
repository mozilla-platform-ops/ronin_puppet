# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class fw::roles::mac_signing {

    case $::fqdn {
        /.*\.(mdc1|mdc2)\.mozilla\.com/: {
            include ::fw::profiles::ssh_from_rejh_logging
            include ::fw::profiles::nrpe_from_nagios
            include ::fw::profiles::dep_signing_from_osx
            include ::fw::profiles::rel_signing_from_osx
            include ::fw::profiles::nightly_signing_from_osx
        }
        default:{
            # Silently skip other DCs
        }
    }
}
