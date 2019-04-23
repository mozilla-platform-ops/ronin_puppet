# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class bitbar_devicepool {

  include ::bitbar_devicepool::systemd_reload

  # create bitbar user & group
  group { 'bitbar':
    ensure => 'present',
    gid    => '1005',
  }

  user { 'bitbar':
    ensure           => 'present',
    uid              => '1005',
    gid              => '1005',
    home             => '/home/bitbar',
    password         => '!!',
    password_max_age => '99999',
    password_min_age => '0',
    shell            => '/bin/bash',
  }

  file { '/home/bitbar':
    ensure => directory,
    owner  => 'bitbar'
  }

  # TODO: add keys

  # TODO: configure sudoers

  vcsrepo { '/home/bitbar/mozilla-bitbar-devicepool':
    ensure   => present,
    provider => git,
    source   => 'https://github.com/bclary/mozilla-bitbar-devicepool.git',
    user     => 'bitbar',
  }

  file { '/etc/systemd/system/bitbar.service':
    ensure => file,
    source => '/home/bitbar/mozilla-bitbar-devicepool/service/bitbar.service',
    notify => [
      Class['bitbar_devicepool::systemd_reload'],
      Service['bitbar'],
    ],
  }

  service { 'bitbar':
    ensure   => running,
    provider => systemd,
    enable   => true,
    require  => Class['bitbar_devicepool::systemd_reload'],
  }
}
