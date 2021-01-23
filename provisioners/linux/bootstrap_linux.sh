#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Purpose: bootstrap a macos mojave host from post install (or image) to a complete puppet run
# This script it intend to be run either run by hand or from an init system after a host has been
# provisioned or re-imaged

# Prerequisites:
#  * wget

set -e
# set -x

# get clock synced. if clock is way off, ssl certs will fail to vaildate
# and puppet won't work.
/etc/init.d/ntp stop
ntpd -q -g  # runs once and force allows huge skews
/etc/init.d/ntp start

# install puppet 6
wget https://apt.puppetlabs.com/puppet6-release-bionic.deb -O /tmp/puppet.deb
dpkg -i /tmp/puppet.deb
apt-get update
apt-get remove -y puppet
apt-get install -y puppet-agent

# Set LANG to UTF-8 otherwise puppet has trouble interperting MacOs tool output eg. dscl
export LANG=en_US.UTF-8
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/puppetlabs/bin"

PUPPET_REPO=${PUPPET_REPO:-"https://github.com/mozilla-platform-ops/ronin_puppet.git"}
PUPPET_BRANCH=${PUPPET_BRANCH:-"master"}
# URL of puppet repo to download
PUPPET_REPO_BUNDLE="${PUPPET_REPO%.git}/archive/${PUPPET_BRANCH}.tar.gz"

# If something fails hard, either exit for interactive or hang for non-interactive
function fail {
    # TODO: emit an critical error event so provisioner knows this node needs to be handled
    echo "${@}"
    # If this is a non-interactive session, hang indefinitely instead of exiting
    if [ "$NONINTERACTIVE" = true ]; then
        echo "Hanging..."
        while true; do sleep 3600; done
    fi
    exit 1
}

# Reset in case getopts has been used previously in the shell.
OPTIND=1

# Parse options. Use of -l flags the script as non-interactive
while getopts ":h?l:" opt; do
    case "$opt" in
        h|\?)
            echo "Usage: ./bootstrap_linux.sh -h               - Show help"
            echo "       ./bootstrap_linux.sh -l /path/logfile - Log output to file"
            echo "       ./bootstrap_linux.sh                  - Interactive mode"
            exit 0
            ;;
        l)
            LOG_PATH=$OPTARG
            NONINTERACTIVE=true
            # touch log file to see if we have write access and fail otherwise
            touch "$LOG_PATH" || fail "Can't write log to ${LOG_PATH}"
            exec >"$LOG_PATH" 2>&1
            ;;
        :)
            echo "Option -$OPTARG requires an argument" >&2
            exit 1
            ;;
    esac
done

# Determine OSTYPE so we can set OS specific paths and alter logic if need be
case "${OSTYPE}" in
  darwin*)  OS='darwin' ;;
  linux*)   OS='linux' ;;
  *)        fail "OS either not detected or not supported!" ;;
esac

# Linux and Darwin share some common paths
if [ $OS == "linux" ] || [ $OS == "darwin" ]; then
    ROLE_FILE='/etc/puppet_role'
    if command -v puppet; then
        PUPPET_BIN=$(command -v puppet)
        FACTER_BIN=$(command -v facter)
    else
        PUPPET_BIN='/opt/puppetlabs/bin/puppet'
        FACTER_BIN='/opt/puppetlabs/bin/facter'
    fi
fi

# This file should be set by the provisioner and is an error to not have a role
# It indicates the role this node is to play
# We may completely change the logic in determine a nodes role such as using an ENC
# but for now, this works
if [ -f "${ROLE_FILE}" ]; then
    ROLE=$(<${ROLE_FILE})
else
    fail "Failed to find puppet role file ${ROLE_FILE}"
fi

# Check that we have the minimum requirements to run puppet
# Since this is a bootstrap script we may actaully install minimum requirements here in the future
if [ ! -x "${PUPPET_BIN}" ]; then
    fail "${PUPPET_BIN} is missing or not executable"
fi

if [ ! -x "${FACTER_BIN}" ]; then
    fail "${FACTER_BIN} is missing or not executable"
fi

# Remove the system git config, since it can't expand ~ when r10k runs git
# https://stackoverflow.com/questions/36908041/git-could-not-expand-include-path-gitcinclude-fatal-bad-config-file-line
rm -rf /usr/local/git/etc/gitconfig

# If this is running on MacOs 10.14 Mojave, we need to monkey patch the directroyservice resource provider
# otherwise user creation fails.
# https://tickets.puppetlabs.com/browse/PUP-9502
# https://tickets.puppetlabs.com/browse/PUP-9449
if [ $OS == "darwin" ] && [ "$(facter os.macosx.version.major)" == "10.14" ]; then
    echo "Monkey patching directoryservice.rb: https://tickets.puppetlabs.com/browse/PUP-9502, https://tickets.puppetlabs.com/browse/PUP-9449"
    sed -i '.bak' 's/-merge/-create/g' '/opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/provider/user/directoryservice.rb'
fi

# Create a temp dir for executing puppet
TMP_PUPPET_DIR=$(mktemp -d /tmp/puppet_working.XXXXXX)
[ -d "${TMP_PUPPET_DIR}" ] || fail "Failed to mktemp puppet working dir"

# Download puppet repository and extract
function get_puppet_repo {
    TMP_DL_DIR=$(mktemp -d -t puppet_download.XXXXXXX)
    [ -d "${TMP_DL_DIR}" ] || fail "Failed to mktemp download dir"

    # Download the puppet repo tarball directly from github
    # We don't use git because some oses don't have git installed by default
    # In the future, we may publish master branch to s3 or some other highly available service since
    # Github has rate limits on downloads.
    while true; do
        echo "Downloading puppet repo: ${PUPPET_REPO_BUNDLE}"
        if HTTP_RES_CODE=$(curl -sL "$PUPPET_REPO_BUNDLE" -o "${TMP_DL_DIR}/puppet.tar.gz" -w "%{http_code}") && [[ "$HTTP_RES_CODE" = "200" ]]; then
            break
        else
            echo "Failed to download puppet repo.  Sleep for 30 seconds before trying again"
            sleep 30
        fi
    done
    # Extract the puppet repo tarball
    tar -zxf "${TMP_DL_DIR}/puppet.tar.gz" --strip 1 -C "${TMP_PUPPET_DIR}" || fail "Failed to extract puppet tar.gz"
    # Clean up the download dir
    rm -rf "${TMP_DL_DIR}"

    # Change to puppet dir
    cd "$TMP_PUPPET_DIR" || fail "Failed to change dir"
    chmod 777 .

    # Inject hiera secrets
    mkdir -p ./data/secrets
    cp /root/vault.yaml ./data/secrets/vault.yaml

    # Get fqdn from facter
    FQDN=$(${FACTER_BIN} networking.fqdn)

    # Create a node definition for this host and write it to the manifests where puppet will pick it up
    cat <<EOF > manifests/nodes/nodes.pp
node '${FQDN}' {
    include ::roles_profiles::roles::${ROLE}
}
EOF
}

# Run puppet and return non-zero if errors are present
function run_puppet {
    # Before running puppet, get puppet repo
    get_puppet_repo

    echo "Running puppet apply"
    # this includes:
    # FACTER_PUPPETIZING so that the manifests know this is a first run of puppet
    # TODO: send logs to syslog? send a puppet report to puppetdb?
    PUPPET_OPTIONS=('--modulepath=./modules:./r10k_modules' '--hiera_config=./hiera.yaml' '--logdest=console' '--color=false' '--detailed-exitcodes' './manifests/')
    export FACTER_PUPPETIZING=true

    # check for 'Error:' in the output; this catches errors even
    # when the puppet exit status is incorrect.
    TMP_LOG=$(mktemp /tmp/puppet-outputXXXXXX)
    [ -f "${TMP_LOG}" ] || fail "Failed to mktemp puppet log file"
    $PUPPET_BIN apply "${PUPPET_OPTIONS[@]}" 2>&1 | tee "${TMP_LOG}"
    retval=$?
    # just in case, if there were any errors logged, flag it as an error run
    if grep -q "^Error:" "${TMP_LOG}"
    then
        retval=1
    fi

    rm "${TMP_LOG}"
    case $retval in
        0|2) return 0;;
        *) return 1;;
    esac
}

# Call the run_puppet function in a endless loop
while ! run_puppet; do
    echo "Puppet run failed; re-trying after 10m"
    sleep 600
done

# Once puppet has completed its initial run we can remove the bootstrap init files
# If it is intended for the host to run puppet after it first puppet
# provisioning, puppet will have already set that up
case "$OS" in
    darwin)
        rm -rf /Library/LaunchDaemons/org.mozilla.bootstrap_linux.plist*
        ;;
esac

# Remove the temp working puppet dir
rm -rf "$TMP_PUPPET_DIR"

# record the installation date (note that this won't appear anywhere on Darwin)
echo "System Installed: $(date)" >> /etc/issue

echo "Success. Rebooting..."

# Success! Let's reboot
/sbin/reboot --force &>/dev/null &

exit 0
