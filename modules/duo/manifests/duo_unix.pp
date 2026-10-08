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
    Enum['source', 'pkg'] $install_method = 'source',
    String $pkg_version       = '2.3.0',
    String $pkg_checksum      = 'ae673a3737fa4301aabeda5b20f61bdc58dd9480ea8916b2c9f80ddc620d5b4f',
) {
    if $enabled {
        # Sanity Check
        if $ikey == '' or $skey == '' or $host == '' {
            fail('ikey, skey, and host must all be defined.')
        }
    }

    # Determine macOS version
    $mac_version = $facts['os']['release']['major']

    if $install_method == 'pkg' {
        # Prebuilt universal pkg from tools/build_duo_unix_pkg.sh. OpenSSL is
        # linked in statically and the payload is only pam_duo.so.
        include packages::setup

        $pkg     = "duo_unix-${pkg_version}-universal.pkg"
        $tmp_pkg = "/tmp/${pkg}"
        $url     = "https://${packages::setup::default_s3_domain}/${packages::setup::default_bucket}/macos/public/common/${pkg}"

        # A missing pam_duo.so with `auth required` in pam.d/sshd blocks all SSH
        $installed = "/bin/sh -c 'pkgutil --pkg-info org.mozilla.relops.duo_unix 2>/dev/null | grep -qx \"version: ${pkg_version}\" && test -f /usr/local/lib/pam/pam_duo.so'"

        exec { 'fetch_duo_unix_pkg':
            command => "/usr/bin/curl -fL -o ${tmp_pkg} ${url}",
            path    => ['/usr/sbin', '/usr/bin', '/bin'],
            unless  => $installed,
            timeout => 120,
        }

        exec { 'verify_duo_unix_pkg':
            command => "/bin/sh -c 'echo \"${pkg_checksum}  ${tmp_pkg}\" | /usr/bin/shasum -a 256 -c -'",
            path    => ['/usr/sbin', '/usr/bin', '/bin'],
            unless  => $installed,
            require => Exec['fetch_duo_unix_pkg'],
        }

        exec { 'install_duo_unix_pkg':
            command => "/usr/sbin/installer -pkg ${tmp_pkg} -target /",
            path    => ['/usr/sbin', '/usr/bin', '/bin'],
            unless  => $installed,
            require => Exec['verify_duo_unix_pkg'],
        }

        $duo_require = Exec['install_duo_unix_pkg']
    } elsif $mac_version == '18' or $mac_version == '19' {
        # macOS 10.14 and 10.15
        include packages::openssl
        include packages::duo_unix

        # Use package-based requirement
        $duo_require = Class['packages::duo_unix']
    } elsif versioncmp($mac_version, '21') {
        # macOS 14+
        notify { "Detected macOS ${mac_version}, treating as 14+":
            message => 'Installing Duo Unix with macOS 14+ script.',
        }

        file { '/usr/local/bin/openssl_duo_mac14.sh':
            ensure => file,
            owner  => 'root',
            group  => 'wheel',
            mode   => '0755',
            source => 'puppet:///modules/duo/openssl_duo_mac14.sh',
        }

        exec { 'install_duo_unix_mac14':
            command   => '/usr/local/bin/openssl_duo_mac14.sh',
            path      => ['/usr/local/bin', '/usr/bin', '/bin'],
            # Run if version doesn't match
            unless    => 'strings /usr/local/lib/pam/pam_duo.so | grep -q "pam_duo/2.2.3"',
            # If install file changes - bypass the version check and run it anyways.
            subscribe => File['/usr/local/bin/openssl_duo_mac14.sh'],
        }

        # Fake a class dependency so require doesn't break
        $duo_require = Exec['install_duo_unix_mac14']
    } else {
        fail("Unsupported macOS version: ${mac_version}")
    }

    file { '/etc/duo':
        ensure => directory,
    }

    # Use the dynamic dependency for `require`
    $conf_present = $enabled ? { true => 'present', default => 'absent' }

    file { '/etc/duo/pam_duo.conf':
        ensure    => $conf_present,
        owner     => 'root',
        group     => 'wheel',
        mode      => '0600',
        show_diff => false,
        content   => template('duo/duo.conf.erb'),
        require   => $duo_require,
    }

    file { '/etc/duo/login_duo.conf':
        ensure    => $conf_present,
        owner     => '_sshd',
        group     => 'wheel',
        mode      => '0600',
        show_diff => false,
        content   => template('duo/duo.conf.erb'),
        require   => $duo_require,
    }

    file { '/etc/ssh/sshd_config':
        ensure  => present,
        owner   => 'root',
        group   => 'wheel',
        mode    => '0644',
        source  => 'puppet:///modules/duo/sshd_config',
        require => $duo_require,
    }

    file { '/etc/pam.d/sshd':
        ensure  => present,
        owner   => 'root',
        group   => 'wheel',
        mode    => '0444',
        source  => 'puppet:///modules/duo/pam_sshd',
        require => $duo_require,
    }
}
