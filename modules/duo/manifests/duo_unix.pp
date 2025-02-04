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
  # Sanity Check
  if $enabled {
    if $ikey == '' or $skey == '' or $host == '' {
      fail('ikey, skey, and host must all be defined.')
    }
  }

  # Determine macOS version
  $mac_version = $facts['os']['release']['major']

  if $mac_version == '10.15' {
    include packages::openssl
    include packages::duo_unix

    # Use package-based requirement
    $duo_require = Class['packages::duo_unix']
  } elsif versioncmp($mac_version, '21') >= 0 or versioncmp($mac_version, '23') >= 0 {
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
      command     => '/usr/local/bin/openssl_duo_mac14.sh',
      path        => ['/usr/local/bin', '/usr/bin', '/bin'],
      refreshonly => true,
      subscribe   => File['/usr/local/bin/openssl_duo_mac14.sh'],
    }

    # Fake a class dependency so require doesn't break
    $duo_require = Exec['install_duo_unix_mac14']
  } else {
    fail("Unsupported macOS version: ${mac_version}")
  }

  # Ensure /etc/duo directory exists
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
    ensure  => file,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    source  => 'puppet:///modules/duo/sshd_config',
    require => $duo_require,
  }

  file { '/etc/pam.d/sshd':
    ensure  => file,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0444',
    source  => 'puppet:///modules/duo/pam_sshd',
    require => $duo_require,
  }
}
