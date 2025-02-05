# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class puppet::periodic (
  String $telegraf_user,
  String $telegraf_password,
  String $puppet_env          = 'production',
  String $puppet_repo         = 'https://github.com/mozilla-platform-ops/ronin_puppet.git',
  # Changing for testing. Do not merge.
  String $puppet_branch       = 'macos-signer-latest',
  String $puppet_notify_email = 'puppet-ronin-reports@mozilla.com',
  String $smtp_relay_host     = lookup({ 'name' => 'smtp_relay_host', 'default_value' => 'localhost' }),
  Hash $meta_data             = {},
) {
  include puppet::setup

  case $facts['os']['name'] {
    'Darwin': {
      file {
        '/Library/LaunchDaemons/com.mozilla.atboot_puppet.plist':
          ensure => absent;

        '/usr/local/bin/run-puppet.sh':
          owner   => 'root',
          group   => 'wheel',
          mode    => '0755',
          content => template('puppet/puppet-darwin-run-puppet.sh.erb');

        '/usr/local/bin/periodic-puppet.sh':
          owner   => 'root',
          group   => 'wheel',
          mode    => '0755',
          content => template('puppet/puppet-darwin-periodic-puppet.sh.erb');

        '/usr/local/bin/periodic_launchctl_wrapper.sh':
          owner  => 'root',
          group  => 'wheel',
          mode   => '0755',
          source => 'puppet:///modules/puppet/periodic_launchctl_wrapper.sh';
      }
    }
    default: {
      fail("${module_name} does not support ${facts['os']['name']}")
    }
  }
}
