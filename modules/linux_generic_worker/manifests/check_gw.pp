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

    require packages::python3

    $pips = [ 'pendulum', 'psutil' ]
    package { $pips:
        ensure   => installed,
        provider => pip3,
        require  => Class['packages::python3'],
    }

    file {
      default:
          owner => 'root',
          group => 'root',
          mode  => '0755';

      ['/opt/relops-check_gw']:
        ensure => directory;

      '/opt/relops-check_gw/check_gw.py':
        ensure => present,
        source => "puppet:///modules/${module_name}/check_gw.py";

      '/lib/systemd/system/check_gw.service':
        source => "puppet:///modules/${module_name}/check_gw.service",
        notify => Exec['reload systemd'];

      '/lib/systemd/system/check_gw.service':
        source => "puppet:///modules/${module_name}/check_gw.timer",
        notify => Exec['reload systemd'];
    }

    service { 'check_gw.timer':
      enable   => true,
      provider => 'systemd',
      require  => File['/lib/systemd/system/check_gw.timer'];
    }

}
