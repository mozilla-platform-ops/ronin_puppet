# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Remove a vault-agent left behind on macOS hosts that no longer include
# vault_agent. Old r8 builders still carry the 2019 install with an empty role
# ID file, so the agent retries auth every ~1.5s forever and the unrotated
# /var/log/vault-agent.log reached 13-14 GB on r8-199/200, enough to push them
# under generic-worker's 20 GiB floor (exit 69 reboot loop).
class vault_agent::absent {
    # Not a service resource: the launchd provider errors on a label with no
    # plist, which is every host this is a no-op on.
    exec { 'bootout-vault-agent':
        command => '/bin/launchctl bootout system/vault-agent',
        onlyif  => '/bin/launchctl print system/vault-agent',
    }

    -> file {
        [
            '/Library/LaunchDaemons/io.vaultproject.vault-agent.plist',
            '/etc/vault-agent-config.hcl',
            '/etc/vault_role_id',
            '/etc/vault_secret_id',
            '/var/log/vault-agent.log',
        ]:
            ensure => absent;
    }
}
