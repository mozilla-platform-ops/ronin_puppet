# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class puppet::atboot (
  String $telegraf_user,
  String $telegraf_password,
  Optional[String] $puppet_env = 'production',
  String $puppet_repo          = 'https://github.com/mozilla-platform-ops/ronin_puppet.git',
  String $puppet_branch        = 'master',
  String $puppet_notify_email  = 'puppet-ronin-reports@mozilla.com',
  String $smtp_relay_host      = lookup({ 'name' => 'smtp_relay_host', 'default_value' => 'localhost' }),
  Hash $meta_data              = {},
) {
  include puppet::setup

  case $facts['os']['name'] {
    'Darwin': {
      file {
        '/Library/LaunchDaemons/com.mozilla.atboot_puppet.plist':
          owner  => 'root',
          group  => 'wheel',
          mode   => '0644',
          source => 'puppet:///modules/puppet/org.mozilla.atboot_puppet.plist';

        '/usr/local/bin/run-puppet.sh':
          owner   => 'root',
          group   => 'wheel',
          mode    => '0755',
          content => template('puppet/puppet-darwin-run-puppet.sh.erb');
      }
    }
    'Ubuntu': {
      case $facts['os']['release']['full'] {
        '18.04', '22.04', '24.04': {
          include linux_packages::openvox
          # yqer is required for github auth integration in run-puppet.sh
          include linux_packages::yqer

          # ensure /etc/puppet exists
          file { '/etc/puppet':
            ensure => directory,
            owner  => 'root',
            group  => 'root',
            mode   => '0755',
          }
          file { '/etc/puppet/lib':
            ensure => directory,
            owner  => 'root',
            group  => 'root',
            mode   => '0755',
          }

          # On Ubuntu 18.04 and 22.04 puppet runs by systemd and on successful result
          # notifies dependent services
          file {
            '/etc/puppet/lib/puppet_state_functions.sh':
              owner  => 'root',
              group  => 'root',
              mode   => '0644',
              source => "puppet:///modules/${module_name}/puppet_state_functions.sh";
            '/usr/local/bin/change_workertype.py':
              owner  => 'root',
              group  => 'root',
              mode   => '0755',
              source => "puppet:///modules/${module_name}/change_workertype.py";
            '/etc/puppet/ronin_settings.example':
              owner  => 'root',
              group  => 'root',
              mode   => '0644',
              source => "puppet:///modules/${module_name}/ronin_settings.example";
            '/lib/systemd/system/run-puppet.service':
              owner   => 'root',
              group   => 'root',
              source  => "puppet:///modules/${module_name}/puppet_2404.service",
              notify  => Exec['reload systemd'],
              require => Class['linux_packages::puppet'];
            '/usr/local/bin/run-puppet.sh':
              owner   => 'root',
              group   => 'root',
              mode    => '0755',
              content => template("${module_name}/puppet-ubuntu-run-puppet.sh.erb");
          }
          # reload systemd daemon
          exec {
            'reload systemd':
              command => '/bin/systemctl daemon-reload';
          }
          # enable the run-puppet service
          service {
            'run-puppet':
              enable   => true,
              provider => 'systemd',
              require  => File['/lib/systemd/system/run-puppet.service'];
          }
          # disable the deb provided service
          service {
            'puppet':
              enable   => false,
              provider => 'systemd';
          }
        }
        default: {
          fail("puppet::atboot support missing for ${facts['os']['release']['full']}")
        }
      }
    }
    default: {
      fail("${module_name} does not support ${facts['os']['name']}")
    }
  }
}
