# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::netperf_tc {
  package { ['iproute2', 'python3']:
    ensure => installed,
  }

  file { '/usr/local/bin/netperf-tc':
    ensure  => file,
    source  => "puppet:///modules/${module_name}/netperf-tc",
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => [Package['iproute2'], Package['python3']],
  }
}
