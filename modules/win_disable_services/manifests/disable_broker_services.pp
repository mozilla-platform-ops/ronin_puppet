# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_broker_services {
  $broker_services = [
    'TimeBrokerSvc',
    'BrokerInfrastructure',
    'SystemEventsBroker',
  ]

  $broker_services.each |String $service_name| {
    service { $service_name:
      ensure => 'stopped',
      enable => false,
    }

    registry_value { "HKLM\\SYSTEM\\CurrentControlSet\\Services\\${service_name}\\Start":
      ensure => 'present',
      type   => dword,
      data   => '4',
    }

    registry_value { "HKLM\\SYSTEM\\CurrentControlSet\\Services\\${service_name}\\UserServiceFlags":
      ensure => 'present',
      type   => dword,
      data   => '0',
    }
  }

  # Ensure services are stopped in the correct order (dependent services first)
  Service['BrokerInfrastructure'] -> Service['SystemEventsBroker']
  Service['TimeBrokerSvc'] -> Service['SystemEventsBroker']
}
