# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class bitbar_devicepool::influx_logger {

  vcsrepo { '/home/bitbar/android-tools':
    ensure   => present,
    provider => git,
    source   => 'https://github.com/mozilla-platform-ops/android-tools.git',
    user     => 'bitbar',
  }

  # create venv and install requirement
  $influx_logger_path = '/home/bitbar/android-tools/worker_health'
  exec { 'create influx_logger pipenv':
      command => "cd ${influx_logger_path} && /home/bitbar/.local/bin/pipenv --python 3.6 install ",
      cwd     => $influx_logger_path,
      user    => 'bitbar',
      # unless  => "/bin/ls ${influx_logger_path}/venv"
  }

  # place systemd unit file
  # file { '/etc/systemd/system/bitbar-last_started_alert.service':
  #   ensure  => file,
  #   replace => 'no',
  #   source  => '/home/bitbar/android-tools/devicepool_last_started_alert/service/last_started_alert.service',
  #   notify  => [
  #     Class['bitbar_devicepool::systemd_reload'],
  #   ],
  # }

  # we need the user to be in this group so sudo isn't required to view logs
  User<| title == bitbar |> { groups +> ['systemd-journal'] }

  # things manually done (in docs):
  # - setting the PAGERDUTY_TOKEN in unit file
  # - enabling this service on primary

}
