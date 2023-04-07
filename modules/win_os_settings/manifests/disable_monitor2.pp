# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_os_settings::disable_monitor2 {
    win_packages::win_zip_pkg { 'controlmymonitor':
        pkg         => 'controlmymonitor.zip',
        creates     => "${facts['custom_win_systemdrive']}\\controlmymonitor\\test.txt",
        destination => "${facts['custom_win_systemdrive']}\\controlmymonitor\\",
    }

}
