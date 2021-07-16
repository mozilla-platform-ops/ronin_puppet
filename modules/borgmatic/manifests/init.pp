# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class borgmatic (
    Hash    $config,
    String  $ssh_public_key,
    String  $ssh_private_key,
    String  $ssh_private_key_path,
    Integer $hour   = 0,
    Integer $minute = 0,
) {

    file { '/etc/borgmatic/config.yaml':
        ensure  => file,
        mode    => '0600',
        content => to_yaml($config),
    }

    file { $ssh_private_key_path:
        ensure  => file,
        content => $ssh_private_key,
        mode    => '0600',
    }

    file { "${ssh_private_key_path}.pub":
        ensure  => file,
        content => $ssh_public_key,
        mode    => '0644',
    }

    file { '/Library/LaunchDaemons/com.mozilla.borgmatic.plist':
        ensure  => file,
        content => template('borgmatic/com.mozilla.borgmatic.plist.erb'),
    }

    # Rotate log
    macos_utils::logrotate { 'borgmatic':
        path  => '/var/log/borgmatic.log',
        mode  => '640',
        count => '6',     # Keep 6 logs
        when  => '$M1D0', # First day of the month @ midnight
    }

    # Ensure borgmatic is enabled
    service { 'com.mozilla.borgmatic':
        ensure    => 'running',
        enable    => 'true',
        subscribe => File['/Library/LaunchDaemons/com.mozilla.borgmatic.plist'],
    }
}
