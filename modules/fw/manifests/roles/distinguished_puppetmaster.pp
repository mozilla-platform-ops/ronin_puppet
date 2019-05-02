# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class fw::roles::distinguished_puppetmaster {

    case $::fqdn {
        /.*\.mdc1\.mozilla\.com/: {
            include ::fw::profiles::bacula_from_mdc1_bacula_host

            include ::fw::profiles::puppetmaster_from_all_releng
            include ::fw::profiles::puppetmaster_sync_from_all_puppetmasters
            include ::fw::profiles::ssh_from_rejh_logging
            include ::fw::profiles::nrpe_from_nagios
        }
        /.*\.mdc2\.mozilla\.com/: {
            include ::fw::profiles::bacula_from_mdc2_bacula_host

            include ::fw::profiles::puppetmaster_from_all_releng
            include ::fw::profiles::puppetmaster_sync_from_all_puppetmasters
            include ::fw::profiles::ssh_from_rejh_logging
            include ::fw::profiles::nrpe_from_nagios
        }
        default: {
            # Silently skip other DCs
        }
    }
}
