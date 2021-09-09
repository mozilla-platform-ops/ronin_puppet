# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class snakepit::worker () {

  # configure users

  ssh_authorized_key { 'root@mlchead':
    user => 'root',
    type => 'ssh-rsa',
    key  => strip(template('snakepit/mlchead_root_ssh_pubkey.key')),
  }

  group { 'snakepit':
    ensure => 'present',
    gid    => 1777
  }

  user { 'snakepit':
    ensure   => 'present',
    home     => '/home/snakepit',
    uid      => 1777,
    password => '!!',  # it has a pw set in prod... what is it?
    shell    => '/bin/bash',
    gid      => 'snakepit',
  }

  # TODO: create mountpoint
  # /mnt/snakepit

  file { '/mnt/snakepit':
    ensure => 'directory',
    path   => '/mnt/snakepit',
    mode   => '0750',  # TODO: what should these be? also update README.md
    owner  => 'snakepit',
    group  => 'snakepit'


  }

  # configure fstab
  mount { '/mnt/snakepit':
    ensure  => 'mounted',
    atboot  => true,
    device  => '192.168.1.1:/snakepit',
    fstype  => 'nfs',
    options => 'nosuid,hard,tcp,bg,noatime',
    pass    => 0
  }

}
