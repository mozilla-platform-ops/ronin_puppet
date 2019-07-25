# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# This profile will include both KMS and WSUS
# KMS portions will continue to grow as support is added for additional platforms

class roles_profiles::profiles::microsoft_network_services {

    case $::operatingsystem {
        'Windows': {
            include win_kms
            if $facts['custom_win_location'] == 'aws' {
                # Hardcode AWS to MDC1 KMS server
                # Datacenter nodes should pick up the KMS server through local DNS
                win_kms::set_server { 'set_aws_kms':
                    server => '10.48.69.100',
                }
            }
            # Bug List
            # kms
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1510828
            # AWS
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1562040
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
