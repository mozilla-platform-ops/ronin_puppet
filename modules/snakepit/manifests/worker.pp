# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class snakepit::worker () {

  # include ::maas::prereqs
  # include apt

  # TODO: configure users

  ssh_authorized_key { 'root@mlchead':
    user => 'root',
    type => 'ssh-rsa',
    key  => template('snakepit/mlchead_root_ssh_pubkey.txt'),
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

  # TODO: configure fstab

}
