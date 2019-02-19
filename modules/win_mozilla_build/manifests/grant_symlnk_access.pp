# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::grant_symlnk_access {

    require win_mozilla_build::hg_install

    exec { 'rename-guest':
        command   => file('win_mozilla_build/grant_symlnk_access.ps1'),
        provider  => powershell,
        logoutput => true,
    }
}
