# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class snakepit::head () {

  # include ::maas::prereqs
  # include apt

  # TODO: configure users

  # create bitbar user & group
  # group { 'bitbar':
  #   ensure => 'present',
  # }

  # user { 'bitbar':
  #   ensure           => 'present',
  #   home             => '/home/bitbar',
  #   password         => '!!',
  #   password_max_age => '99999',
  #   password_min_age => '0',
  #   shell            => '/bin/bash',
  #   gid              => 'bitbar',
  # }

  # TODO: configure NFS packages/service
  # TODO: configure /etc/exports

}
