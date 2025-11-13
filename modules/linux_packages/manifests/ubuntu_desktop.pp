# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# This should pull whatever package(s) are appropriate to get a full desktop
# environment
class linux_packages::ubuntu_desktop {
  case $facts['os']['name'] {
    'Ubuntu': {
      case $facts['os']['release']['full'] {
        '18.04': {
          package {
            'ubuntu-desktop':
              ensure => latest;
          }
        }
        '24.04': {
          package {
            'ubuntu-desktop':
              ensure => latest;
          }

          # TODO: on 2404, we install via a server image with systemctl-networkd providing networking by default
          # when we install the desktop package, NetworkManager is installed and it causes the system to fail to
          # handle DNS resolution until rebooted.
          #
          # Simulate a reboot.
          #
          # TODO: run the following commands.
          # sudo systemctl restart systemd-networkd
          # sudo systemctl restart systemd-resolved
          # sudo systemctl restart NetworkManager
          # sudo netplan apply
          #
          # note: CI doesn't like this, but it makes hw systems happy.
          if $facts['running_in_test_kitchen'] != 'true' {
            exec { 'simulate reboot after ubuntu-desktop install':
              command     => '/usr/bin/systemctl restart systemd-networkd && /usr/bin/systemctl restart systemd-resolved && /usr/bin/systemctl restart NetworkManager && /usr/sbin/netplan apply',
              refreshonly => true,
              subscribe   => Package['ubuntu-desktop'],
            }
          }
        }
        default: {
          fail("Ubuntu ${facts['os']['release']['full']} is not supported")
        }
      }
    }
    default: {
      fail("Cannot install on ${facts['os']['name']}")
    }
  }
}
