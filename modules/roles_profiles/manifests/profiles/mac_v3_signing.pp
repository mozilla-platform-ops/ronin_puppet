# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::mac_v3_signing {

    case $::operatingsystem {
        'Darwin': {

            class { 'puppet::atboot':
                # "pinning"
                # for the first setup of a node type, the provisioner script in the image must have a valid node
                # then, pinning will apply on the next run atboot:
                puppet_repo   => 'https://github.com/davehouse/ronin_puppet.git',
                puppet_branch => 'notarization',
            }

            # we can add worker setup here like in gecko_t_osx_1014_generic_worker.pp

            include dirs::tools

            contain packages::python3
            file { '/tools/python3':
                    ensure  => 'link',
                    target  => '/usr/local/bin/python3',
                    require => Class['packages::python3'],
            }
            contain packages::virtualenv

        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
