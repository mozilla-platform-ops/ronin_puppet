# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class disable_services () {
  case $facts['os']['name'] {
    'Ubuntu': {
      # These packages are required by ubuntu-desktop, so we can't uninstall them.
      # Instead, install but disable them.
      case $facts['os']['release']['full'] {
        '18.04', '22.04', '24.04': {
          # acpi removed because it can't be disabled this way
          #   (never worked in build-puppet/16.04)
          $install_and_disable = ['cups', 'anacron',
            'whoopsie', 'modemmanager', 'apport',
          'avahi-daemon']
          # 18.04 Moonshots use NetworkManager for DHCP. Stopping it leaves
          # networking without its manager after boot and across lease renewals.
          # Explicitly enable it to repair hosts disabled by older catalogs.
          $keep_network_manager = $facts['os']['release']['full'] == '18.04'
          $network_manager_state = $keep_network_manager ? {
            true    => running,
            default => stopped,
          }
          package { 'network-manager':
            ensure => latest,
          }
          service { 'network-manager':
            ensure   => $network_manager_state,
            enable   => $keep_network_manager,
            provider => 'systemd',
            require  => Package['network-manager'],
          }
          package {
            $install_and_disable:
              ensure => latest;
          }
          service {
            $install_and_disable:
              ensure   => stopped,
              provider => 'systemd',
              enable   => false,
              require  => Package[$install_and_disable];
          }

          # disable apport via defaults also
          file {
            '/etc/default/apport':
              source => "puppet:///modules/${module_name}/apport";
          }

          # this package and service have different names
          package {
            'bluez':
              ensure => latest;
          }
          service {
            'bluetooth':
              ensure   => stopped,
              provider => 'systemd',
              enable   => false,
              require  => Package['bluez'];
          }

          # disable periodic apt actions
          file {
            '/etc/apt/apt.conf.d/10periodic':
              ensure => file,
              owner  => 'root',
              group  => 'root',
              source => "puppet:///modules/${module_name}/10periodic";

            '/etc/apt/apt.conf.d/20auto-upgrades':
              ensure => file,
              owner  => 'root',
              group  => 'root',
              source => "puppet:///modules/${module_name}/20auto-upgrades";
          }

          # stop 'unattended-upgrades' processes, disabled in /etc/apt/apt.conf.d/20auto-upgrades
          # but still showing up
          service { 'unattended-upgrades':
            ensure => stopped,
            enable => false,
          }
        }
        default: {
          fail("Unrecognized Ubuntu version ${facts['os']['release']['full']}")
        }
      }
    }
    default: {
      fail("gui is not supported on ${facts['os']['name']}")
    }
  }
}
