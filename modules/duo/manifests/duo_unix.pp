# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class duo::duo_unix (
    Boolean $enabled          = false,
    String $ikey              = '',
    String $skey              = '',
    String $host              = '',
    String $group             = '',
    String $http_proxy        = '',
    String $fallback_local_ip = 'no',
    String $failmode          = 'safe',
    String $pushinfo          = 'no',
    String $autopush          = 'no',
    String $prompts           = '3',
    String $accept_env_factor = 'no',
) {
    if $enabled {
        # Sanity Check
        if $ikey == '' or $skey == '' or $host == '' {
            fail('ikey, skey, and host must all be defined.')
        }
    }

    include packages::openssl
    include packages::duo_unix

    # Do not leave duo config around if disabled
    $conf_present = $enabled ? {
        true => 'present',
        default => 'absent',
    }

    file { '/etc/duo':
        ensure => directory,
    }

    file { '/etc/duo/pam_duo.conf':
        ensure    => $conf_present,
        owner     => 'root',
        group     => 'wheel',
        mode      => '0600',
        show_diff => false,
        content   => template('duo/duo.conf.erb'),
        require   => Class['packages::duo_unix'],
    }

    file { '/etc/duo/login_duo.conf':
        ensure    => $conf_present,
        owner     => '_sshd',
        group     => 'wheel',
        mode      => '0600',
        show_diff => false,
        content   => template('duo/duo.conf.erb'),
        require   => Class['packages::duo_unix'],
    }

    file { '/etc/ssh/sshd_config':
        ensure  => present,
        owner   => 'root',
        group   => 'wheel',
        mode    => '0644',
        source  => 'puppet:///modules/duo/sshd_config',
        require => Class['packages::duo_unix'],
    }

    file { '/etc/pam.d/sshd':
        ensure  => present,
        owner   => 'root',
        group   => 'wheel',
        mode    => '0444',
        source  => 'puppet:///modules/duo/pam_sshd',
        require => Class['packages::duo_unix'],
    }
}
