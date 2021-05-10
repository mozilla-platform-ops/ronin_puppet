# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::puppet_agent {

    $package_version = lookup('puppet_agent.package_version')
    $collection      = split($package_version, '[.]')[0]

    case $::operatingsystem {
        'Darwin': {
            class {'::puppet_agent':
                collection      => "puppet${collection}",
                package_version => $package_version,
                is_pe           => false,
                service_names   => []
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
