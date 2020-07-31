# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::virtual_drivers {

    case $::operatingsystem {
        'Windows': {

            $version = lookup('win-worker.vac.version')
            # Obfuscating command flags because the developer does not intend for the arguments to be public available
            # For the command contact the developer https://vac.muzychenko.net/en/support.htm
            $flags = lookup('vac_flags')

            class { 'win_packages::vac':
                version => $version,
                flags   => $flags,

            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1656286
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
