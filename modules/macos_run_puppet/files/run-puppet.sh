#!/bin/bash
# shellcheck disable=SC1090

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

### ---------------------------------------------
### 1. Constants & Variable Definitions
### ---------------------------------------------
set -e
export LANG=en_US.UTF-8
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/puppetlabs/bin"
export GIT_REPO_URL="$PUPPET_REPO"
export GIT_BRANCH="$PUPPET_BRANCH"

# Optional override settings file
if [ -f "$SETTINGS_FILE" ]; then
    # shellcheck source=/opt/puppet_environments/ronin_settings
    echo "Loading settings from $SETTINGS_FILE..."
    source "$SETTINGS_FILE"
else
    echo "No override settings file found at $SETTINGS_FILE; using script defaults."
fi

# Change before merge
: "${PUPPET_REPO:=https://github.com/mozilla-platform-ops/ronin_puppet.git}"
: "${PUPPET_BRANCH:=master}"
: "${PUPPET_ROLE_FILE:=/etc/puppet_role}"
: "${PUPPET_BIN:=/opt/puppetlabs/bin/puppet}"
: "${FACTER_BIN:=/opt/puppetlabs/bin/facter}"

### ---------------------------------------------
### 2. Function Definitions
### ---------------------------------------------

fail() {
    echo "${@}"
    exit 1
}

extract_username_from_url() {
    local url="$1"
    if [[ "$url" =~ git@github.com:([^/]+)/.* ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$url" =~ https://github.com/([^/]+)/.* ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "unknown"
    fi
}

get_puppet_repo() {
    if [ ! -d "$LOCAL_PUPPET_REPO" ]; then
        fail "Local Puppet repository not found at $LOCAL_PUPPET_REPO"
    fi
    cd "$LOCAL_PUPPET_REPO" || fail "Failed to change directory to $LOCAL_PUPPET_REPO"

    # Inject Hiera Secrets
    mkdir -p ./data/secrets

    if [ ! -f /var/root/vault.yaml ]; then
        echo "vault.yaml not found — exiting gracefully."
        exit 0
    fi

    cp /var/root/vault.yaml ./data/secrets/vault.yaml
    chmod 0600 ./data/secrets/vault.yaml

    # Get FQDN from Facter
    FQDN=$("$FACTER_BIN" networking.fqdn)

    # Create a node definition for this host
    cat <<EOF > manifests/nodes/nodes.pp
node '$FQDN' {
    include ::roles_profiles::roles::$ROLE
}
EOF
}

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

### ---------------------------------------------
### 3. Main Execution Logic
### ---------------------------------------------

GIT_USERNAME=$(extract_username_from_url "$GIT_REPO_URL")
LOCAL_PUPPET_REPO="/opt/puppet_environments/${GIT_USERNAME}/ronin_puppet"
SETTINGS_FILE="/opt/puppet_environments/ronin_settings"

echo "Using Puppet Repo: $GIT_REPO_URL"
echo "Using Branch: $GIT_BRANCH"

# Ensure Puppet Role is Set
if [ -f "$PUPPET_ROLE_FILE" ]; then
    ROLE=$(<"$PUPPET_ROLE_FILE")
else
    fail "Failed to find Puppet role file $PUPPET_ROLE_FILE"
fi

# Ensure Puppet & Facter are Installed
[ -x "$PUPPET_BIN" ] || fail "Puppet is missing or not executable."
[ -x "$FACTER_BIN" ] || fail "Facter is missing or not executable."

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
    mkdir -p "$(dirname "$LOCAL_PUPPET_REPO")"
    git clone --branch "$GIT_BRANCH" "$GIT_REPO_URL" "$LOCAL_PUPPET_REPO" || fail "Failed to clone Puppet repository"
fi

# Retry Puppet Until Success, Checking for Updates Before Each Retry
while true; do
    echo "Running Puppet apply..."

    if run_puppet; then
        echo "Puppet apply succeeded!"
        break
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
