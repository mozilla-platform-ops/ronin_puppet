# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::mozilla_build {

    case $::operatingsystem {
        'Windows': {

        $current_version = $facts['mozbld_ver']
        $version         = '3.2'
        $install_path    = "${facts['custom_win_systemdrive']}\\mozilla-build"

            class { 'win_mozilla_build':
                current_version => $current_version,
                version         => $version,
                install_path    => $install_path,
            }
            # Bug List
            # https://bugzilla.mozilla.org/show_bug.cgi?id=1524440
        }
        default: {
            fail("${::operatingsystem} not supported")
        }
    }
}
