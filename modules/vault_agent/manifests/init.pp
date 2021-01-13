# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class vault_agent (
    String $vault_addr_url = 'https://vault.relops.mozops.net:8200',
) {

    # Install the vault binary
    include packages::vault

    # These gems are install in puppet's Ruby lib
    # and are required by hiera-vault
    package { 'vault-puppetpath-gem':
        ensure   => 'present',
        name     => 'vault',
        provider => 'puppet_gem',
    }

    package { 'debouncer-puppetpath-gem':
        ensure   => 'present',
        name     => 'debouncer',
        provider => 'puppet_gem',
    }

    file {
        # Make sure these secret files have the correct permissions and ownership
        [ '/etc/vault_approle_id', '/etc/vault_approle_secret' ]:
            ensure => present,
            mode   => '0600',
            notify => Service['vault-agent'];


        # Create vault agent config
        '/etc/vault-agent-config.hcl':
            ensure  => file,
            mode    => '0600',
            content => template('vault_agent/vault-agent-config.hcl.erb'),
            notify  => Service['vault-agent'];
    }

    # Add VAULT_ADDR env system-wide which points at the local vault agent
    shellprofile::file { 'vault_agent':
            ensure  => 'present',
            content => template("${module_name}/vault_env.sh.erb");
    }

    case $facts['os']['name'] {
        'Darwin': {
            # Launchd vault-agent service
            file {
                '/Library/LaunchDaemons/io.vaultproject.vault-agent.plist':
                    ensure => file,
                    source => 'puppet:///modules/vault_agent/vault-agent.plist',
                    notify => Service['vault-agent'],
            }

            # Rotate /var/log/vault-agent.log
            macos_utils::logrotate { 'vault-agent':
                path     => '/var/log/vault-agent.log',
                pid_file => '/var/run/vault-agent.pid',
            }
        }
        'Ubuntu': {
            # Setup systemd vault-agent service
            file {
                '/etc/systemd/system/vault-agent.service':
                    ensure => file,
                    source => 'puppet:///modules/vault_agent/vault-agent.service';

                # Set global VAULT_ADDR path to localhost so calls to vault will point to the local vault agent
                '/etc/profile.d/vault_env.sh':
                    ensure  => file,
                    content => 'export VAULT_ADDR=http://127.0.0.1:8200\n';
            }

            # TODO: Log rotate vault agent for linux
            # Probably using the logrotate module from the forge
        }
        default: { fail("${facts['os']['name']} is not supported") }
    }

    # Ensure vault-agent service is enabled and running
    service { 'vault-agent':
        ensure => 'running',
        enable => 'true',
    }
}
