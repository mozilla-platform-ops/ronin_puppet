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

  # configure root's allowed ssh keys
  file { '/root/.ssh':
    ensure => 'directory',
    mode   => '0700',
    owner  => 'root',
    group  => 'root'
  }

  file { '/root/.ssh/authorized_keys':
    mode    => '0600',
    owner   => 'root',
    group   => 'root',
    content => strip(template('snakepit/head_root_authorized_keys.key')),
  }

  # create snakepit app dir
  file { '/snakepit':
    ensure => 'directory',
    path   => '/snakepit',
    mode   => '0700',
    owner  => 'snakepit',
    group  => 'snakepit'
  }

  # install NFS server
  package {
      'nfs-kernel-server':
          ensure => present;
  }

  service { 'nfs-server':
    ensure  => 'running',
    enable  => true,
    require => Package['nfs-kernel-server'],
  }

  # configure /etc/exports
  file { '/etc/exports':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('snakepit/etc_exports'),
    notify  => Service['nfs-server'],
  }

  # TODO: configure number of NFS daemon threads
  # root@mlchead:/etc/default# cat nfs-kernel-server
  # Number of servers to start up
  # RPCNFSDCOUNT=32

  # TODO: configure more snakepit app dirs?

  # TODO: add relops users, add relops users to sudoers

  # TODO: configure nfsd
  # 32 on mlchead, set in /etc/defaults/nfs-kernel-server
  # RPCNFSDCOUNT=8

}
