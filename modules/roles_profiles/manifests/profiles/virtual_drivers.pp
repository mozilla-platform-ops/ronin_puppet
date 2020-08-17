# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::virtual_drivers {

    case $::operatingsystem {
        'Windows': {

            # Obfuscating command flags because the developer does not intend for the arguments to be public available
            # For the command contact the developer https://vac.muzychenko.net/en/support.htm
            $flags    = lookup('vac_flags')
            $vac_dir  = lookup('windows.dir.vac')
            $version  = lookup('win-worker.vac.version')
            $work_dir = "${vac_dir}\\vac${version}"

            class { 'win_packages::vac':
                flags    => $flags,
                srcloc   => lookup('windows.s3.ext_pkg_src'),
                vac_dir  => $vac_dir,
                version  => $version,
                work_dir => $work_dir
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1656286
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
