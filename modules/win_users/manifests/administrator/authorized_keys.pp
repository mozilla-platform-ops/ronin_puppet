# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_users::administrator::authorized_keys (
    String $win_audit
) {
    $auth_keys_dir = "${facts['custom_win_systemdrive']}\\Users\\Administrator\\.ssh"

    file { $auth_keys_dir:
        ensure => directory,
    }
    file { "${auth_keys_dir}\\authorized_keys":
        content => win_audit,
    }
}
