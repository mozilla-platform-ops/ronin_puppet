# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class bitbar_devicepool::devicepool {

  $devicepool_path = '/home/bitbar/mozilla-bitbar-devicepool'

  # clone repo
  vcsrepo { '/home/bitbar/mozilla-bitbar-devicepool':
    ensure   => present,
    provider => git,
    source   => 'https://github.com/mozilla-platform-ops/mozilla-bitbar-devicepool.git',
    user     => 'bitbar',
  }

  # set poetry config options
  exec { 'set poetry options':
      command => '/home/bitbar/.local/bin/poetry config --local virtualenvs.in-project true',
      cwd     => $devicepool_path,
      user    => 'bitbar',
      unless  => "/bin/ls ${devicepool_path}/poetry.toml",
  }

  # create venv and install requirement
  exec { 'create devicepool venv and install requirements':
      command => '/home/bitbar/.local/bin/poetry install',
      cwd     => $devicepool_path,
      user    => 'bitbar',
      unless  => "/bin/ls ${devicepool_path}/.venv"
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
