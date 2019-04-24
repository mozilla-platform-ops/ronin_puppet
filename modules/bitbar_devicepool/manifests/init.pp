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

  # TODO: configure sudoers

  # TODO: eventually place bitbar env file (encrypt somehow)
  # - do manually for now

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

  # we set to stopped as we don't expect to run this past initial convergence
  # multiple devicepools running is more problematic than none
  # TODO: figure out how to make one node have it enabled/running
  service { 'bitbar':
    ensure   => stopped,
    provider => systemd,
    enable   => false,
    require  => Class['bitbar_devicepool::systemd_reload'],
  }
}
