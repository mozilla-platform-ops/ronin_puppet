# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_time (
    String $servers,
) {
  case $::operatingsystem {
    'Ubuntu': {
      case $::operatingsystemrelease {
        '18.04':  {
          # 1804 uses timesyncd vs ntpd
          file {
              '/etc/systemd/timesyncd.conf':
                  owner   => 'root',
                  group   => 'wheel',
                  mode    => '0644',
                  content => template("${module_name}/timesyncd.conf.erb");
          }
        }
        default: {
          # previously the 'ntp' community r10k was used
          # class { 'ntp':
          #     servers => [$ntp_server]
          # }
          fail("Ubuntu ${::operatingsystemrelease} is not supported")
        }
      }
    }
    default: {
      fail("Cannot install on ${::operatingsystem}")
    }
  }
}
