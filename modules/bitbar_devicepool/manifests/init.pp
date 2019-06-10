# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class bitbar_devicepool {

  include ::bitbar_devicepool::systemd_reload

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

  # we set to stopped as we don't expect to run this past initial convergence
  # multiple devicepools running is more problematic than none
  # TODO: figure out how to make one node have it enabled/running
  # service { 'bitbar':
  #   ensure   => stopped,
  #   provider => systemd,
  #   enable   => false,
  #   require  => Class['bitbar_devicepool::systemd_reload'],
  # }

  # TODO: eventually place bitbar env file (encrypt somehow)
  notify {" \n\n \
.88b  d88.  .d8b.  d8b   db db    db  .d8b.  db \n \
88'YbdP`88 d8' `8b 888o  88 88    88 d8' `8b 88 \n \
88  88  88 88ooo88 88V8o 88 88    88 88ooo88 88 \n \
88  88  88 88~~~88 88 V8o88 88    88 88~~~88 88 \n \
88  88  88 88   88 88  V888 88b  d88 88   88 88booo. \n \
YP  YP  YP YP   YP VP   V8P ~Y8888P' YP   YP Y88888P \n \
 \n \
 \n \
.d8888. d888888b d88888b d8888b. .d8888. \n \
88'  YP `~~88~~' 88'     88  `8D 88'  YP \n \
`8bo.      88    88ooooo 88oodD' `8bo. \n \
  `Y8b.    88    88~~~~~ 88~~~     `Y8b.  \n \
db   8D    88    88.     88      db   8D  \n \
`8888Y'    YP    Y88888P 88      `8888Y' \n \
\n \
If this is the first time converging this host, please \n \
place the bitbar env file at /etc/bitbar/bitbar.env \n \
and run: \n \
     sudo chown root:bitbar /etc/bitbar/bitbar.env \n \
     sudo chmood 660 /etc/bitbar/bitbar.env \n\n":}

}
