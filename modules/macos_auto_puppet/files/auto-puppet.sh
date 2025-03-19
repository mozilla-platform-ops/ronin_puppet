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

# Override defaults with values from /etc/puppet/ronin_settings if the file exists
if [ -f "/etc/puppet/ronin_settings" ]; then
    echo "Loading settings from /etc/puppet/ronin_settings..."
    source /etc/puppet/ronin_settings

    export GIT_REPO_URL="${PUPPET_REPO:-$GIT_REPO_URL}"
    export GIT_BRANCH="${PUPPET_BRANCH:-$GIT_BRANCH}"
    export PUPPET_MAIL="${PUPPET_MAIL:-}"
    export WORKER_TYPE_OVERRIDE="${WORKER_TYPE_OVERRIDE:-}"
fi

echo "Using Puppet Repo: $GIT_REPO_URL"
echo "Using Branch: $GIT_BRANCH"

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

# Clone or update Puppet repository
if [ -d "$LOCAL_PUPPET_REPO/.git" ]; then
    echo "Checking existing Puppet repository..."
    cd "$LOCAL_PUPPET_REPO" || fail "Failed to change directory to Puppet repository"

    CURRENT_REMOTE_URL=$(git remote get-url origin 2>/dev/null)

    if [ "$CURRENT_REMOTE_URL" != "$GIT_REPO_URL" ]; then
        echo "Repository URL has changed. Removing old repository..."
        cd ..
        rm -rf "$LOCAL_PUPPET_REPO"
        echo "Cloning new Puppet repository..."
        git clone --branch "$GIT_BRANCH" "$GIT_REPO_URL" "$LOCAL_PUPPET_REPO" || fail "Failed to clone Puppet repository"
    else
        echo "Checking for updates in Puppet repository..."
        git fetch origin "$GIT_BRANCH" || fail "Failed to fetch latest changes"

        LOCAL_COMMIT=$(git rev-parse HEAD)
        REMOTE_COMMIT=$(git rev-parse "origin/$GIT_BRANCH")

        if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
            echo "Updates found. Pulling latest changes..."
            git reset --hard "origin/$GIT_BRANCH" || fail "Failed to reset to latest commit"
        else
            echo "Already up-to-date. No changes needed."
        fi
    fi
else
    echo "Cloning fresh Puppet repository..."
    git clone --branch "$GIT_BRANCH" "$GIT_REPO_URL" "$LOCAL_PUPPET_REPO" || fail "Failed to clone Puppet repository"
fi

# Ensure Puppet Repository Exists
get_puppet_repo() {
    if [ ! -d "$LOCAL_PUPPET_REPO" ]; then
        fail "Local Puppet repository not found at $LOCAL_PUPPET_REPO"
    fi
    cd "$LOCAL_PUPPET_REPO" || fail "Failed to change directory to $LOCAL_PUPPET_REPO"

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

# Retry Puppet Until Success, Checking for Updates Before Each Retry
while true; do
    echo "Running Puppet apply..."

    if run_puppet; then
        echo "Puppet apply succeeded!"
        exit 0
    fi

    echo "Puppet apply failed. Checking for updates before retrying..."

    cd "$LOCAL_PUPPET_REPO" || fail "Failed to enter Puppet repository directory"

    git fetch origin "$GIT_BRANCH" || fail "Failed to fetch latest changes"
    LOCAL_COMMIT=$(git rev-parse HEAD)
    REMOTE_COMMIT=$(git rev-parse "origin/$GIT_BRANCH")

    if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
        echo "New changes detected! Updating repository..."
        git reset --hard "origin/$GIT_BRANCH" || fail "Failed to reset to latest commit"
        echo "Repository updated. Retrying Puppet apply..."
    else
        echo "No new changes found. Retrying Puppet apply in 60 seconds..."
    fi

    sleep 60
done

# Clean Up & Finish
rm -rf "$TMP_PUPPET_DIR"
echo "System Installed: $(date)" >> /etc/issue

exit 0
