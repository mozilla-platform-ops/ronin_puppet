#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Purpose: bootstrap a macos mojave host from post install (or image) to a complete puppet run
# This script is intended to be run either by hand or from an init system after a host has been
# provisioned or re-imaged

# Prerequisites:
#  * curl
#  * tar w/gzip
#  * Puppet agent 6.x.x

export LANG=en_US.UTF-8
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/puppetlabs/bin"

# Pointing to the local Puppet repo
LOCAL_PUPPET_REPO="/var/root/puppet/ronin_puppet"
export VAULT_ADDR=http://127.0.0.1:8200
VAULT_TOKEN="$(cat /etc/vault_token 2> /dev/null)"
export VAULT_TOKEN

function fail {
    echo "${@}"
    if [ "$NONINTERACTIVE" = true ]; then
        echo "Hanging..."
        while true; do sleep 3600; done
    fi
    exit 1
}

OPTIND=1
while getopts ":h?l:" opt; do
    case "$opt" in
        h|\?)
            echo "Usage: ./bootstrap_mojave.sh -h               - Show help"
            echo "       ./bootstrap_mojave.sh -l /path/logfile - Log output to file"
            echo "       ./bootstrap_mojave.sh                  - Interactive mode"
            exit 0
            ;;
        l)
            LOG_PATH=$OPTARG
            NONINTERACTIVE=true
            touch "$LOG_PATH" || fail "Can't write log to ${LOG_PATH}"
            exec >"$LOG_PATH" 2>&1
            ;;
        :)
            echo "Option -$OPTARG requires an argument" >&2
            exit 1
            ;;
    esac
done

case "${OSTYPE}" in
  darwin*)  OS='darwin' ;;
  linux*)   OS='linux' ;;
  *)        fail "OS either not detected or not supported!" ;;
esac

if [ $OS == "linux" ] || [ $OS == "darwin" ]; then
    ROLE_FILE='/etc/puppet_role'
    PUPPET_BIN='/opt/puppetlabs/bin/puppet'
    FACTER_BIN='/opt/puppetlabs/bin/facter'
fi

if [ -f "${ROLE_FILE}" ]; then
    ROLE=$(<"${ROLE_FILE}")
else
    fail "Failed to find puppet role file ${ROLE_FILE}"
fi

if [ ! -x "${PUPPET_BIN}" ]; then
    fail "${PUPPET_BIN} is missing or not executable"
fi

if [ ! -x "${FACTER_BIN}" ]; then
    fail "${FACTER_BIN} is missing or not executable"
fi

rm -rf /usr/local/git/etc/gitconfig

if [ $OS == "darwin" ] && [ "$(facter os.macosx.version.major)" == "10.14" ]; then
    echo "Monkey patching directoryservice.rb"
    sed -i '.bak' 's/-merge/-create/g' '/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/provider/user/directoryservice.rb'
fi

# Instead of downloading, use the existing local Puppet repository
function get_puppet_repo {
    # Ensure the local puppet repository exists
    if [ ! -d "${LOCAL_PUPPET_REPO}" ]; then
        fail "Local Puppet repository not found at ${LOCAL_PUPPET_REPO}"
    fi

    # Change to the local Puppet repo directory
    cd "$LOCAL_PUPPET_REPO" || fail "Failed to change directory to ${LOCAL_PUPPET_REPO}"

    # Inject hiera secrets
    mkdir -p ./data/secrets
    cp /var/root/vault.yaml ./data/secrets/vault.yaml

    # Get fqdn from facter
    FQDN=$(${FACTER_BIN} networking.fqdn)

    # Create a node definition for this host and write it to the manifests where puppet will pick it up
    cat <<EOF > manifests/nodes/nodes.pp
node '${FQDN}' {
    include ::roles_profiles::roles::${ROLE}
}
EOF
}

function run_puppet {
    get_puppet_repo

    echo "Running puppet apply"
    PUPPET_OPTIONS=('--modulepath=./modules:./r10k_modules' '--hiera_config=./hiera.yaml' '--debug' '--logdest=console,/tmp/puppet_bootstrap.log' '--color=false' '--detailed-exitcodes' './manifests/')
    export FACTER_PUPPETIZING=true

    TMP_LOG=$(mktemp /tmp/puppet-outputXXXXXX)
    [ -f "${TMP_LOG}" ] || fail "Failed to mktemp puppet log file"
    $PUPPET_BIN apply "${PUPPET_OPTIONS[@]}" 2>&1 | tee "${TMP_LOG}"
    retval=$?
    if grep -q "^Error:" "${TMP_LOG}"; then
        retval=1
    fi

    rm "${TMP_LOG}"
    case $retval in
        0|2) return 0;;
        *) return 1;;
    esac
}

while ! run_puppet; do
    echo "Puppet run failed; re-trying after 10m"
    sleep 600
done

case "$OS" in
    darwin)
        rm -rf /Library/LaunchDaemons/org.mozilla.bootstrap_mojave.plist*
        ;;
esac

rm -rf "$TMP_PUPPET_DIR"
echo "System Installed: $(date)" >> /etc/issue

/sbin/reboot

exit 0
