# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_broker_services {
  service { 'TimeBrokerSvc':
    ensure => 'stopped',
    enable => false,
  }

  registry_value { 'HKLM\SYSTEM\CurrentControlSet\Services\TimeBrokerSvc\Start':
    ensure => 'present',
    type   => dword,
    data   => '4',
  }
  registry_value { 'HKLM\SYSTEM\CurrentControlSet\Services\TimeBrokerSvc\UserServiceFlags':
    ensure => 'present',
    type   => dword,
    data   => '0',
  }

  service { 'BrokerInfrastructure':
    ensure => 'stopped',
    enable => false,
  }
  registry_value { 'HKLM\SYSTEM\CurrentControlSet\Services\BrokerInfrastructure\Start':
    ensure => 'present',
    type   => dword,
    data   => '4',
  }
  registry_value { 'HKLM\SYSTEM\CurrentControlSet\Services\BrokerInfrastructure\UserServiceFlags':
    ensure => 'present',
    type   => dword,
    data   => '0',
  }

  service { 'SystemEventsBroker':
    ensure => 'stopped',
    enable => false,
  }
  registry_value { 'HKLM\SYSTEM\CurrentControlSet\Services\SystemEventsBroker\Start':
    ensure => 'present',
    type   => dword,
    data   => '4',
  }
  registry_value { 'HKLM\SYSTEM\CurrentControlSet\Services\SystemEventsBroker\UserServiceFlags':
    ensure => 'present',
    type   => dword,
    data   => '0',
  }
}
