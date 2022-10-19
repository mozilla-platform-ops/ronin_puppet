# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::scoop {

    case $facts['os']['name'] {
        'Windows': {
            # specifically using scoop to install sscahce
            # scoop can be used to install other packages but we will need to restructure this profile
            # https://github.com/mozilla/sccache#installation
            # https://scoop.sh/
            # https://forge.puppetlabs.com/modules/jovandeginste/scoop

            include scoop
            include win_packages::scoop

        }
        default: {
            fail("${$facts['os']['name']} not supported")
        }
    }
}
