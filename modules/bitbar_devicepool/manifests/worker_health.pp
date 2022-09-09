# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class bitbar_devicepool::worker_health {
  $desired_packages = ['python3-pip']
  ensure_packages($desired_packages, { 'ensure' => 'present' })

  exec { 'install pipenv':
    command => '/usr/bin/pip3 install pipenv',
    user    => 'bitbar',
    unless  => '/bin/ls /home/bitbar/.local/bin/pipenv',
  }

  # TODO: set a variable with python version and just use it
  case $facts['os']['release']['full'] {
    '18.04' : {
      # create venv and install requirement
      $influx_logger_path = '/home/bitbar/android-tools/worker_health'
      exec { 'create and install worker_health pipenv':
        command => '/home/bitbar/.local/bin/pipenv --python 3.6 install',
        cwd     => $influx_logger_path,
        user    => 'bitbar',
        unless  => '/bin/ls /home/bitbar/.local/share/virtualenvs/worker_health-*/',
      }
    }
    '22.04': {
      # create venv and install requirement
      $influx_logger_path = '/home/bitbar/android-tools/worker_health'
      exec { 'create and install worker_health pipenv':
        command => '/home/bitbar/.local/bin/pipenv --python 3.10 install',
        cwd     => $influx_logger_path,
        user    => 'bitbar',
        unless  => '/bin/ls /home/bitbar/.local/share/virtualenvs/worker_health-*/',
      }
    }

    default: {
      fail("Unrecognized Ubuntu version ${facts['os']['release']['full']}")
    }
  }

  # we need the user to be in this group so sudo isn't required to view logs
  User<| title == bitbar |> { groups +> ['systemd-journal'] }

  # place systemd unit files
  file { '/etc/systemd/system/bitbar-slack_alert.service':
    ensure  => file,
    replace => 'no',
    source  => '/home/bitbar/android-tools/worker_health/service/slack_alert.service',
    notify  => [
      Class['bitbar_devicepool::systemd_reload'],
    ],
  }

  file { '/etc/systemd/system/bitbar-influx_logger.service':
    ensure  => file,
    replace => 'no',
    source  => '/home/bitbar/android-tools/worker_health/service/influx_logger.service',
    notify  => [
      Class['bitbar_devicepool::systemd_reload'],
    ],
  }

  # things manually done (in docs):
  # - configure ~/.bitbar_slack_alert.toml
  # - configure ~/.bitbar_influx_logger.toml
  # - enabling these service on primary
}
