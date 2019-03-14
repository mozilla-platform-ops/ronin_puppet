# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define users::user_ssh_config (
    String $home,
    String $group,
    String $username = $title,
    Array $ssh_keys = [],
) {

    # Manage the users .ssh directory
    file { "${home}/.ssh":
        ensure  => directory,
        mode    => '0700',
        owner   => $username,
        group   => $group,
        purge   => true,
        recurse => true,
        force   => true,
        backup  => false,
    }

    # Manage authorized keys
    file { "${home}/.ssh/authorized_keys":
        owner   => $username,
        group   => $group,
        mode    => '0600',
        content => template('users/ssh_authorized_keys.erb'),
        require => File["${home}/.ssh"],
    }
}
