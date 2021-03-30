# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class bitbar_devicepool::devicepool {

  # clone repo
  vcsrepo { '/home/bitbar/mozilla-bitbar-devicepool':
    ensure   => present,
    provider => git,
    source   => 'https://github.com/mozilla-platform-ops/mozilla-bitbar-devicepool.git',
    user     => 'bitbar',
  }

  # create venv and install requirement
  $devicepool_path = '/home/bitbar/mozilla-bitbar-devicepool'
  exec { 'create devicepool venv and install requirements':
      command =>"/usr/bin/virtualenv venv && ${devicepool_path}/venv/bin/pip install -r requirements.txt",
      cwd     => $devicepool_path,
      user    => 'bitbar',
      unless  => "/bin/ls ${devicepool_path}/venv"
  }

  # place apk files required for starting jobs via API
  file { '/home/bitbar/mozilla-bitbar-devicepool/files/aerickson-empty-test.zip':
    ensure => file,
    source => 'puppet:///modules/bitbar_devicepool/aerickson-empty-test.zip',
    owner  => 'bitbar',
    group  => 'bitbar',
    mode   => '0644',

  }
  file { '/home/bitbar/mozilla-bitbar-devicepool/files/aerickson-Testdroid.apk':
    ensure => file,
    source => 'puppet:///modules/bitbar_devicepool/aerickson-Testdroid.apk',
    owner  => 'bitbar',
    group  => 'bitbar',
    mode   => '0644',
  }

  # place systemd unit file for devicepool
  file { '/etc/systemd/system/bitbar.service':
    ensure => file,
    source => '/home/bitbar/mozilla-bitbar-devicepool/service/bitbar.service',
    notify => [
      Class['bitbar_devicepool::systemd_reload'],
    ],
  }

}
