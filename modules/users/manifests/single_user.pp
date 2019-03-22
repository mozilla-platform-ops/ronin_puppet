# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define users::single_user (
    String $username             = $title,
    String $shell                = '/bin/bash',
    Array $ssh_keys              = [],
    Array $groups                = [],
    Optional[String] $password   = undef,
    Optional[String] $salt       = undef,
    Optional[String] $iterations = undef,
) {

    # include resources common to ALL users
    include users::global

    $group = $::operatingsystem ? {
        'Darwin' => 'staff',
        default  => $username
    }

    $home = $::operatingsystem ? {
        'Darwin' => "/Users/${username}",
        default  => "/home/${username}"
    }

    case $facts['os']['family'] {
        'Darwin': {
            # If values for password, salt and iteration are passed, then set the user with a password
            if $password and $salt and $iterations {
                user { $username:
                    gid        => $group,
                    shell      => $shell,
                    home       => $home,
                    groups     => $groups,
                    comment    => $username,
                    password   => $password,
                    salt       => $salt,
                    iterations => $iterations,
                }
            } else {
                user { $username:
                    gid     => $group,
                    shell   => $shell,
                    home    => $home,
                    groups  => $groups,
                    comment => $username,
                }
            }
        }
        default: {
            fail("${module_name} does not support ${facts['os']['family']}")
        }
    }

    # Create users home directory and populate it with skeleton files and users custom files
    file { $home:
        source  => [ "puppet:///modules/users/home_dirs/${username}", 'puppet:///modules/users/home_dirs/skel' ],
        recurse => remote,
        mode    => 'g-w,o-rwx',
        owner   => $username,
        group   => $group,
        require => User[$username],
    }

    users::user_ssh_config { $username:
        group    => $group,
        home     => $home,
        ssh_keys => $ssh_keys,
        require  => File[$home],
    }
}
