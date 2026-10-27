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
  Optional[Hash] $github_deploy_keys = undef,
) {
  include puppet::setup

  # Keep managing the legacy owner-only checkout during the transition.  This
  # lets the last legacy-wrapper run restore safe permissions before the new
  # wrapper starts using its repository-specific checkout on the next boot.
  $puppet_repo_owner = regsubst($puppet_repo, '^https?://[^/]+/([^/]+)/.*$', '\1')
  $puppet_owner_dir  = "/etc/puppet/environments/${puppet_repo_owner}"
  $working_dir       = "${puppet_owner_dir}/code"

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
          file { '/etc/puppet/environments':
            ensure  => directory,
            owner   => 'root',
            group   => 'root',
            mode    => '0755',
            require => File['/etc/puppet'],
          }
          file { $puppet_owner_dir:
            ensure  => directory,
            owner   => 'root',
            group   => 'root',
            mode    => '0755',
            require => File['/etc/puppet/environments'],
          }
          file { '/etc/puppet/lib':
            ensure => directory,
            owner  => 'root',
            group  => 'root',
            mode   => '0755',
          }
          file {
            '/root/.ssh':
              ensure => directory,
              owner  => 'root',
              group  => 'root',
              mode   => '0700';
            '/root/.ssh/known_hosts':
              ensure  => file,
              owner   => 'root',
              group   => 'root',
              mode    => '0644',
              source  => "puppet:///modules/${module_name}/github_known_hosts",
              require => File['/root/.ssh'];
          }

          # Install every supported repository's available key before an operator
          # switches repositories. Remove keys whose Vault entries were revoked.
          [
            'mozilla-platform-ops/ronin_puppet',
            'aerickson/ronin_puppet-private',
            'mozilla-platform-ops/ronin_puppet-private',
          ].each |String $github_deploy_key_slug| {
            $github_deploy_key_name = regsubst($github_deploy_key_slug, '[-/]', '_', 'G')
            $github_deploy_key_path = "/root/.ssh/${github_deploy_key_name}_deploy_key"
            $github_deploy_key      = dig($github_deploy_keys, $github_deploy_key_slug, 'private_key')

            if $github_deploy_key =~ String and $github_deploy_key != '' {
              file { $github_deploy_key_path:
                ensure    => file,
                owner     => 'root',
                group     => 'root',
                mode      => '0600',
                content   => Sensitive($github_deploy_key),
                show_diff => false,
                require   => File['/root/.ssh'];
              }
            } else {
              file { $github_deploy_key_path:
                ensure => absent,
              }
            }
          }

          # On Ubuntu 18.04 and 22.04 puppet runs by systemd and on successful result
          # notifies dependent services
          file {
            $working_dir:
              ensure  => directory,
              owner   => 'root',
              group   => 'root',
              mode    => '0755',
              require => File[$puppet_owner_dir];
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
            '/usr/local/bin/puppet-run-marker':
              ensure => file,
              owner  => 'root',
              group  => 'root',
              mode   => '0755',
              source => "puppet:///modules/${module_name}/puppet-run-marker";
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
              # TODO: ideally we wouldn't specify the provider of puppet, just the need
              require => Class['linux_packages::openvox'];
            '/usr/local/bin/run-puppet.sh':
              owner   => 'root',
              group   => 'root',
              mode    => '0755',
              content => template("${module_name}/puppet-ubuntu-run-puppet.sh.erb");
            '/usr/local/bin/run-puppet':
              ensure => link,
              target => '/usr/local/bin/run-puppet.sh';
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
          # must run after openvox-agent is installed, as apt removing
          # puppet-agent (a conflict) can re-enable the service
          service {
            'puppet':
              ensure   => stopped,
              enable   => false,
              provider => 'systemd',
              require  => Class['linux_packages::openvox'];
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
