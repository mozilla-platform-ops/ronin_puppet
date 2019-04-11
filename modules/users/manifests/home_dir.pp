# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define users::home_dir (
    String $user,
    String $group,
    String $home    = $title,
    Array $ssh_keys = [],
) {

    case $facts['os']['family'] {
        'Darwin': {
            # Create user home directory and populate it with skeleton files and users custom files
            file { $home:
                source  => [ "puppet:///modules/users/home_dirs/${user}", 'puppet:///modules/users/home_dirs/skel' ],
                recurse => remote,
                mode    => 'g-w,o-rwx',
                owner   => $user,
                group   => $group,
                require => User[$user],
            }

            # Create standard directories in home dir
            file {
                "/Users/${user}/Library":
                    ensure  => directory,
                    owner   => $user,
                    group   => $group,
                    mode    => '0755',
                    require => File["/Users/${user}"];
                "/Users/${user}/Library/Preferences":
                    ensure  => directory,
                    owner   => $user,
                    group   => $group,
                    mode    => '0700',
                    require => File["/Users/${user}/Library"];
                "/Users/${user}/Library/Preferences/ByHost":
                    ensure  => directory,
                    owner   => $user,
                    group   => $group,
                    mode    => '0700',
                    require => File["/Users/${user}/Library/Preferences"];
                "/Users/${user}/Library/Application Support":
                    ensure  => 'directory',
                    owner   => $user,
                    group   => $group,
                    mode    => '0755',
                    require => File["/Users/${user}/Library"];
            }

            users::user_ssh_config { $user:
                group    => $group,
                home     => $home,
                ssh_keys => $ssh_keys,
                require  => File[$home],
            }
        }
        default: {
            fail("${module_name} does not support ${facts['os']['family']}")
        }
    }
}
