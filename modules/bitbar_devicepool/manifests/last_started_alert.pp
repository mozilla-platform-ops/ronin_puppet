# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class bitbar_devicepool::last_started_alert {

  vcsrepo { '/home/bitbar/android-tools':
    ensure   => present,
    provider => git,
    source   => 'https://github.com/mozilla-platform-ops/android-tools.git',
    user     => 'bitbar',
  }

  # TODO: create venv

  # place systemd unit file
    file { '/etc/systemd/system/bitbar-last_started_alert.service':
    ensure => file,
    source => '/home/bitbar/android-tools/devicepool_last_started_alert/service/last_started_alert.service',
    notify => [
      Class['bitbar_devicepool::systemd_reload'],
    ],
  }

  # TODO: things to add to docs or bootstrap script:
  # - setting the PAGERDUTY_TOKEN in unit file
  # - enabling this service on primary

}
