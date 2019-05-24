# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define users::single_user (
    String $user                 = $title,
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
        default  => $user
    }

    $home = $::operatingsystem ? {
        'Darwin' => "/Users/${user}",
        default  => "/home/${user}"
    }

    # SIP workaround; module assumes sip is off
    case $::operatingsystem {
        'Darwin': {
            file { [ '/var/db/dslocal/nodes/Default',
                     '/var/db/dslocal/nodes/Default/users' ]:
                ensure  => 'directory',
                recurse => true,
                mode    => 'g+r',
            }
        }
    }

    case $facts['os']['family'] {
        'Darwin', 'Debian': {
            # If values for password, salt and iteration are passed, then set the user with a password
            if $password and $salt and $iterations {
                user { $user:
                    gid        => $group,
                    shell      => $shell,
                    home       => $home,
                    groups     => $groups,
                    comment    => $user,
                    password   => $password,
                    salt       => $salt,
                    iterations => $iterations,
                }
            } else {
                user { $user:
                    gid     => $group,
                    shell   => $shell,
                    home    => $home,
                    groups  => $groups,
                    comment => $user,
                }
            }
        }
        default: {
            fail("${module_name} does not support ${facts['os']['family']}")
        }
    }

    # Create home dir
    users::home_dir { $home:
        user     => $user,
        group    => $group,
        ssh_keys => $ssh_keys,
    }
}
