# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# configures the appropriate service to ensure time is synced
class linux_ntp {
  case $facts['os']['name'] {
    'Ubuntu': {
      case $facts['os']['release']['full'] {
        /^24\.04/: {
          # setup timesyncd for 24.04
          file { '/etc/systemd/timesyncd.conf.d':
            ensure => 'directory',
            owner  => 'root',
            group  => 'root',
            mode   => '0755',
          }
          file { '/etc/systemd/timesyncd.conf.d/mozilla.conf':
            ensure => 'file',
            source => "puppet:///modules/${module_name}/timesyncd_mozilla.conf",
            owner  => 'root',
            group  => 'root',
            mode   => '0644',
          }
        }
        default: {
          fail("Unsupported Ubuntu version for NTP setup: ${facts['os']['release']['full']}")
        }
      }
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}
