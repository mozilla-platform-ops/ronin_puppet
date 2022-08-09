# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_filesystem::google_auth_dir {

    $google_dir = "${facts['custom_win_roninprogramdata']}\\maintainsystem.ps1"

    file { $google_dir :
        ensure => directory,
    }
    file { "${google_dir}\\Auth":
        ensure => directory,
    }
}
