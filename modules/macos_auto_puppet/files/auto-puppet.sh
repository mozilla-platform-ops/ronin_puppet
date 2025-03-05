#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Purpose: Bootstrap a macOS 14+ host from post-install (or image) to a complete Puppet run.

export LANG=en_US.UTF-8
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/puppetlabs/bin"

# Puppet configuration
LOCAL_PUPPET_REPO="/Users/relops/Desktop/puppet/ronin_puppet"
PUPPET_ROLE_FILE="/etc/puppet_role"
PUPPET_BIN="/opt/puppetlabs/bin/puppet"
FACTER_BIN="/opt/puppetlabs/bin/facter"
GIT_REPO_URL="https://github.com/mozilla-platform-ops/ronin_puppet.git"
GIT_BRANCH="auto_puppet_v2"

# Vault configuration
export VAULT_ADDR="http://127.0.0.1:8200"
VAULT_TOKEN="$(cat /etc/vault_token 2>/dev/null)"
export VAULT_TOKEN

# Fail function
fail() {
    echo "${@}"
    exit 1
}

# Ensure Puppet Role is Set
if [ -f "$PUPPET_ROLE_FILE" ]; then
    ROLE=$(<"$PUPPET_ROLE_FILE")
else
    fail "Failed to find Puppet role file $PUPPET_ROLE_FILE"
fi

# Ensure Puppet & Facter are Installed
if [ ! -x "$PUPPET_BIN" ]; then
    fail "Puppet is missing or not executable."
fi

if [ ! -x "$FACTER_BIN" ]; then
    fail "Facter is missing or not executable."
fi

# Remove existing Puppet repository and re-clone it
rm -rf "$LOCAL_PUPPET_REPO"
git clone --branch "$GIT_BRANCH" "$GIT_REPO_URL" "$LOCAL_PUPPET_REPO" || fail "Failed to clone Puppet repository"

# Ensure Puppet Repository Exists
get_puppet_repo() {
    if [ ! -d "$LOCAL_PUPPET_REPO" ]; then
        fail "Local Puppet repository not found at $LOCAL_PUPPET_REPO"
    fi
    cd "$LOCAL_PUPPET_REPO" || fail "Failed to change directory to $LOCAL_PUPPET_REPO"

    # Inject Hiera Configuration
    sudo tee "$LOCAL_PUPPET_REPO/hiera.yaml" > /dev/null << 'EOF'
---
version: 5
defaults:
  data_hash: yaml_data
  datadir: data

hierarchy:
  - name: "local"
    path: "/var/root/vault.yaml"

  - name: "Per-role data"
    path: "roles/%%{facts.puppet_role}.yaml"

  - name: "Per-role Windows"
    path: "roles/%%{facts.custom_win_role}.yaml"

  - name: "Per-OS defaults"
    path: "os/%%{facts.os.family}.yaml"

  - name: "Secrets generated from Vault"
    path: "secrets/vault.yaml"

  - name: "Common data to all"
    path: "common.yaml"
EOF

    # Inject Hiera Secrets
    mkdir -p ./data/secrets
    cp /var/root/vault.yaml ./data/secrets/vault.yaml

    # Get FQDN from Facter
    FQDN=$("$FACTER_BIN" networking.fqdn)

    # Create a node definition for this host
    cat <<EOF > manifests/nodes/nodes.pp
node '$FQDN' {
    include ::roles_profiles::roles::$ROLE
}
EOF
}

# Run Puppet
run_puppet() {
    get_puppet_repo
    echo "Running puppet apply"

    PUPPET_OPTIONS=(
        "--modulepath=./modules:./r10k_modules:/etc/puppetlabs/code/environments/production/modules"
        "--hiera_config=./hiera.yaml"
        "--logdest=console"
        "--color=false"
        "--detailed-exitcodes"
        "./manifests/"
    )

    export FACTER_PUPPETIZING=true
    TMP_LOG=$(mktemp /tmp/puppet-outputXXXXXX)
    [ -f "$TMP_LOG" ] || fail "Failed to create temp Puppet log file."

    $PUPPET_BIN apply "${PUPPET_OPTIONS[@]}" 2>&1 | tee "$TMP_LOG"
    retval=$?

    if grep -q "unable to open database \"/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$TMP_LOG"; then
        echo "Detected TCC.db issue. A reboot is required."
        sudo shutdown -r now
        exit 0
    fi

    if grep -q "^Error:" "$TMP_LOG"; then
        retval=1
    fi

    rm "$TMP_LOG"

    case $retval in
        0|2) return 0;;
        *) return 1;;
    esac
}

# Retry Puppet Until Success
while ! run_puppet; do
    echo "Puppet run failed; re-trying in 60 seconds"
    sleep 60
done

# Clean Up & Finish
rm -rf "$TMP_PUPPET_DIR"
echo "System Installed: $(date)" >> /etc/issue

exit 0
