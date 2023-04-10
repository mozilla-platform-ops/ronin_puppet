# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::intel_drivers {
    if $facts['dmi']['product']['name'] == 'NUC*' {
        class { 'win_packages::drivers::intel_gfx' :
            version => lookup('win-worker.driver.gfx.version')
        }
    }
}
