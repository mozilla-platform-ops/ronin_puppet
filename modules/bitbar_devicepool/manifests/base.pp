# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class bitbar_devicepool::base {
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
    gid              => 'bitbar',
  }

  # create directories
  file { '/home/bitbar':
    ensure => directory,
    owner  => 'bitbar',
    group  => 'bitbar',
    mode   => '0770',
  }
  file { '/etc/bitbar':
    ensure => directory,
    owner  => 'root',
    group  => 'bitbar',
    mode   => '0750',
  }

  # create wheel group
  group { 'wheel':
    ensure => 'present',
  }

  # disable login for departed users
  User<| title == bclary |> {
    shell => '/usr/sbin/nologin',
    groups => 'bclary',
  }

  # add users to groups:
  # - wheel: sudo without password
  # - bitbar: to access devicepool stuff
  # - adm: to view all systemd logs
  $relops = lookup('user_groups.relops', Array, undef, undef)
  $relops.each |String $user| {
    User<| title == $user |> { groups +> ['wheel', 'bitbar', 'adm'] }
  }

  # set timezone to pacific
  class { 'timezone':
    timezone   => 'UTC',
    rtc_is_utc => true,
  }

  # install packages
  #  - vim, screen are nice-to-haves

  case $facts['os']['release']['full'] {
    '18.04': {
      $desired_packages = ['vim', 'screen', 'git', 'python', 'python3', 'virtualenv']
    }
    '22.04': {
      $desired_packages = ['vim', 'screen', 'git', 'python3', 'python3-virtualenv']
    }
    default: {
      fail("Unrecognized Ubuntu version ${facts['os']['release']['full']}")
    }
  }
  ensure_packages($desired_packages, { 'ensure' => 'present' })
}
