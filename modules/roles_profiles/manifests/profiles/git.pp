# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::git {

    case $::operatingsystem {
        'Windows': {

        $git_version = lookup('win-worke.git.version')
        $srcloc      = lookup('windows.s3.ext_pkg_src')
        $current     = $facts['custom_win_git_version']
        $pkgdir      = $facts['custom_win_temp_dir']

            class { 'win_packages::git':
                needed_version  => $git_version,
                pkg_source      => $srcloc,
                local_dir       => $pkgdir,
                current_version => $current,
            }
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
