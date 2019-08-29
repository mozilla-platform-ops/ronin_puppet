# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class bitbar_devicepool::telegraf {

  # install telegraf
  $_operatingsystem = downcase($facts['operatingsystem'])
  $telegraf_repo_location        = 'https://repos.influxdata.com/'

  apt::source { 'influxdata':
    comment  => 'Mirror for InfluxData packages',
    location => "${telegraf_repo_location}${_operatingsystem}",
    release  => $facts['lsbdistcodename'],
    repos    => 'stable',
    key      => {
      'id'     => '05CE15085FC09D18E99EFB22684A14CF2582E0C5',
      'source' => "${telegraf_repo_location}influxdb.key",
    },
    before   => Exec['apt_update']
  }

  $desired_packages = ['telegraf']
  ensure_packages($desired_packages,{
    'ensure' => 'present',
    require => Exec['apt_update'],
  })

  # TODO: place config
  file { '/etc/telegraf/telegraf.conf':
    ensure  => file,
    source  => 'puppet:///modules/bitbar_devicepool/telegraf.conf',
  }

  # TOOD: restart service if config changed
  # - hmm, but we need to sed the config file before it's correct...

}
