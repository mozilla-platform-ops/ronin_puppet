# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class snakepit::head () {

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

  # TODO: configure NFS packages/service
  # TODO: configure /etc/exports

}
