# Linux Provisioners

Scripts for bootstrapping and maintaining Linux (Ubuntu) hosts managed by ronin_puppet.

## Scripts

### `bootstrap_linux.sh`

Bootstraps a fresh Linux host from post-install to a fully converged Puppet run. Installs
[OpenVox](https://voxpupuli.org/openvox/) (an open-source Puppet agent), configures NTP,
and runs Puppet until it succeeds. Supports Ubuntu 18.04 and 24.04.

**Prerequisites:**
- `/root/vault.yaml` — hiera secrets file
- `/etc/puppet_role` — puppet role for this host (e.g. `gecko_t_linux_talos`)
- `wget` installed

**Usage:**

```bash
# Interactive mode
sudo ./bootstrap_linux.sh

# Non-interactive (logs to file)
sudo ./bootstrap_linux.sh -l /var/log/bootstrap.log

# Use a specific repo/branch during development
PUPPET_REPO="https://github.com/youruser/ronin_puppet.git" \
PUPPET_BRANCH="your-branch" \
sudo ./bootstrap_linux.sh
```

### `deliver_linux.sh`

Delivers bootstrap prerequisites to a remote host over SSH and prints the commands needed
to kick off the bootstrap. Auto-detects whether to connect as `relops` or `root`.

**Usage:**

```bash
./deliver_linux.sh <hostname> <puppet-role>

# Example
./deliver_linux.sh devicepool-0.relops.mozops.net gecko_t_linux_talos
```

The script copies `bootstrap_linux.sh`, `vault.yaml`, and (optionally) a `ronin_settings`
file to the remote host and sets the role file. It then prints the SSH commands to run the
bootstrap.

### `update_linux.sh`

Updates `vault.yaml` (hiera secrets) on an already-bootstrapped host. Can optionally
update the puppet role with `force`.

**Usage:**

```bash
./update_linux.sh <hostname> [role] [force]

# Update secrets only
./update_linux.sh myhost.example.com

# Update secrets and change role (requires 'force')
./update_linux.sh myhost.example.com gecko_t_linux_talos force
```

### `bootstrap_bitbar_devicepool.sh`

Bootstrap script specific to `bitbar_devicepool` hosts. Installs Puppet 7, r10k, and runs
a masterless Puppet apply against a git-cloned copy of the repo.

## Configuration

### `vault.yaml`

Hiera secrets file. Must be present at `/root/vault.yaml` on the target host before
bootstrap runs. A `vault.yaml.bak` and `vault.yaml.bak2` are kept as backups.

### `ronin_settings` / `ronin_settings.dis`

Optional settings file that overrides `PUPPET_REPO`, `PUPPET_BRANCH`, and other variables.
Rename to `ronin_settings` (drop the `.dis` extension) to activate it. When present,
`deliver_linux.sh` will copy it to `/etc/puppet/ronin_settings` on the remote host.

## Testing

Bootstrap scripts can be tested locally using Docker via the script in `test/`.

```bash
# Test against Ubuntu 24.04
./test/test_bootstrap.sh 24.04

# Test against Ubuntu 18.04
./test/test_bootstrap.sh 18.04
```

The test script spins up an Ubuntu container, copies `bootstrap_linux.sh` into it, and
verifies that `openvox-agent` installs successfully. The script uses `SKIP_NTP=true` since
Docker containers don't have an init system — NTP setup is expected to fail, but
`openvox-agent` installation is validated.

Requires Docker to be installed and running.
