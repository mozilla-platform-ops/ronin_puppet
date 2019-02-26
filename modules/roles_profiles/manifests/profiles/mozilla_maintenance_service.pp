# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::mozilla_maintenance_service {

    case $::operatingsystem {
        'Windows': {
            include win_mozilla_maintenance_service

            win_mozilla_maintenance_service::certificate_install { 'MozFakeCA':
                cert_key        => '0',
                registry_name   => 'Mozilla Corporation',
                registry_issuer => 'Thawte Code Signing CA - G2',
            }
            win_mozilla_maintenance_service::certificate_install { 'MozFakeCA_2017-10-13':
                cert_key        => '1',
                registry_name   => 'Mozilla Fake SPC',
                registry_issuer => 'Mozilla Fake CA',
            }
            win_mozilla_maintenance_service::certificate_install { 'MozRoot_cer':
                cert_key        => '2',
                registry_name   => 'Mozilla Corporation',
                registry_issuer => 'DigiCert SHA2 Assured ID Code Signing CA'
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1529631
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
