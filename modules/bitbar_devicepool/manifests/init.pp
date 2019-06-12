# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class bitbar_devicepool {

  include ::bitbar_devicepool::systemd_reload

  # set timezone to pacific
  class { 'timezone':
    timezone   => 'UTC',
    rtc_is_utc => true,
  }

  # vim is a requirement
  $desired_packages = ['vim', 'screen', 'python', 'virtualenv', 'git']

  package { $desired_packages:
    ensure => installed,
  }

  # create bitbar user & group
  group { 'bitbar':
    ensure => 'present',
  }

  user { 'bitbar':
    ensure           => 'present',
    home             => '/home/bitbar',
    password         => '!!',
    password_max_age => '99999',
    password_min_age => '0',
    shell            => '/bin/bash',
    groups           => ['bitbar'],
  }

  # create directories
  file { '/home/bitbar':
    ensure => directory,
    owner  => 'bitbar',
    group  => 'bitbar',
    mode   => '0770'
  }
  file { '/etc/bitbar':
    ensure => directory,
    owner  => 'root',
    group  => 'bitbar',
    mode   => '0750'
  }

  # create wheel group
  group { 'wheel':
    ensure => 'present',
  }

  # add users to wheel group
  User<| title == bclary |> { groups +> ['wheel', 'bitbar'] }
  $relops = lookup('user_groups.relops', Array, undef, undef)
  $relops.each |String $user| {
      User<| title == $user |> { groups +> ['wheel', 'bitbar']}
  }

  # clone repo
  vcsrepo { '/home/bitbar/mozilla-bitbar-devicepool':
    ensure   => present,
    provider => git,
    source   => 'https://github.com/bclary/mozilla-bitbar-devicepool.git',
    user     => 'bitbar',
  }

  # place apk files required for starting jobs via API
  file { '/home/bitbar/mozilla-bitbar-devicepool/files/aerickson-empty-test.zip':
    ensure => file,
    source => 'puppet:///modules/bitbar_devicepool/aerickson-empty-test.zip',
    owner  => 'bitbar',
    group  => 'bitbar',
    mode   => '0644',

  }
  file { '/home/bitbar/mozilla-bitbar-devicepool/files/aerickson-Testdroid.apk':
    ensure => file,
    source => 'puppet:///modules/bitbar_devicepool/aerickson-Testdroid.apk',
    owner  => 'bitbar',
    group  => 'bitbar',
    mode   => '0644',
  }

  # place systemd unit file for devicepool
  file { '/etc/systemd/system/bitbar.service':
    ensure => file,
    source => '/home/bitbar/mozilla-bitbar-devicepool/service/bitbar.service',
    notify => [
      Class['bitbar_devicepool::systemd_reload'],
      # Service['bitbar'],
    ],
  }

}
