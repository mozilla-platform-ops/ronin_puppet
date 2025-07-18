# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# the workaround for https://bugs.launchpad.net/ubuntu/+source/gnome-settings-daemon/+bug/1764417
# in init.pp didn't work... run this script regularly to detect hosts where g-w not running
# due to the bug and restart
#
# also:
#   - fix hosts with bad ntp

class linux_generic_worker::check_gw () {
  require linux_packages::py3
  require linux_packages::psutil_py3

  # block for ubuntu and then selecting between 24.04 and 18.04,22.04
  case $facts['os']['name'] {
    'Ubuntu': {
      # 24 install via apt, 18 and 22 install via pip3
      if $facts['os']['release']['full'] == '24.04' {
        package { 'python3-pendulum':
          ensure   => latest,
          provider => apt,
          require  => Class['linux_packages::py3'],
        }
      } elsif $facts['os']['release']['full'] in ['18.04', '20.04', '22.04'] {
        $pips = ['pendulum']
        package { $pips:
          ensure   => installed,
          provider => pip3,
          require  => Class['linux_packages::py3'],
        }
      }
      else {
        fail("Cannot install check_gw deps on ${facts['os']['name']} ${facts['os']['release']['major']}")
      }
    }
    default: {
      fail("Cannot install check_gw deps on ${facts['os']['name']}")
    }
  }

  # handled above
  #
  # $pips = ['pendulum']
  # package { $pips:
  #   ensure   => installed,
  #   provider => pip3,
  #   require  => Class['linux_packages::py3'],
  # }

  file {
    default:
      owner => 'root',
      group => 'root',
      mode  => '0644';

    ['/opt/relops-check_gw']:
      ensure => directory,
      mode   => '0755';

    '/opt/relops-check_gw/check_gw.py':
      ensure => file,
      mode   => '0755',
      source => "puppet:///modules/${module_name}/check_gw.py";

    '/lib/systemd/system/check_gw.service':
      source => "puppet:///modules/${module_name}/check_gw.service",
      notify => Exec['reload systemd'];

    '/lib/systemd/system/check_gw.timer':
      source => "puppet:///modules/${module_name}/check_gw.timer",
      notify => Exec['reload systemd'];
  }

  service { 'check_gw.timer':
    enable   => true,
    provider => 'systemd',
    require  => File['/lib/systemd/system/check_gw.timer'];
  }
}
