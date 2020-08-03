# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::virtual_drivers {

    case $::operatingsystem {
        'Windows': {

            # Obfuscating command flags because the developer does not intend for the arguments to be public available
            # For the command contact the developer https://vac.muzychenko.net/en/support.htm
            $flags = lookup('vac_flags')

            class { 'win_packages::vac':
                creates => "${facts['custom_win_system32']}\\vac.exe",
                flags   => $flags,
                srcloc  => lookup('windows.s3.ext_pkg_src'),
                vac_dir => lookup('windows.dir.vac'),
                version =>lookup('win-worker.vac.version'),
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1656286
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
