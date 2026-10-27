#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Purpose: bootstrap a Linux host from post install (or image) to a complete puppet run
# This script it intend to be run either run by hand or from an init system after a host has been
# provisioned or re-imaged

# Prerequisites:
#  * wget

# usage during development:
#  PUPPET_REPO="https://github.com/aerickson/ronin_puppet.git" \
#  PUPPET_BRANCH="aerickson-071825-2404_pt2" \
#  ./bootstrap_linux.sh

set -e
set -x


#
# variables/constants
#

export DEBIAN_FRONTEND=noninteractive
export APT_ARGS='-o Dpkg::Options::=--force-confold'

# Set LANG to UTF-8 for Puppet and command output.
export LANG=en_US.UTF-8
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/puppetlabs/bin"

PUPPET_REPO=${PUPPET_REPO:-"https://github.com/mozilla-platform-ops/ronin_puppet.git"}
PUPPET_BRANCH=${PUPPET_BRANCH:-"master"}
# URL of puppet repo to download
PUPPET_REPO_BUNDLE="${PUPPET_REPO%.git}/archive/${PUPPET_BRANCH}.tar.gz"

# Reset in case getopts has been used previously in the shell.
OPTIND=1


#
# functions
#

# Download puppet repository and extract
function get_puppet_repo {
    # Start retries from a fresh checkout inside the private bootstrap directory.
    cd "${BOOTSTRAP_DIR}" || fail "Failed to change to bootstrap dir"
    rm -rf -- "${TMP_PUPPET_DIR}"
    mkdir -m 0755 "${TMP_PUPPET_DIR}" || fail "Failed to create puppet working dir"

    # if PUPPET_BRANCH is master, grab the tarball, otherwise clone
    if [ "$PUPPET_BRANCH" = "master" ]; then
        echo "Puppet branch is master, downloading tarball"

        TMP_DL_DIR=$(mktemp -d "${BOOTSTRAP_DIR}/download.XXXXXXX")
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
        tar -zxf "${TMP_DL_DIR}/puppet.tar.gz" --no-same-permissions --strip 1 -C "${TMP_PUPPET_DIR}" || fail "Failed to extract puppet tar.gz"
        # Clean up the download dir
        rm -rf "${TMP_DL_DIR}"
    else
        echo "Puppet branch is $PUPPET_BRANCH, cloning repository"

        # Clone the puppet repo
        git clone --depth 1 --branch "$PUPPET_BRANCH" "$PUPPET_REPO" "$TMP_PUPPET_DIR" || fail "Failed to clone puppet repo"
        echo "Puppet repo cloned successfully. Git info:"
        cd "$TMP_PUPPET_DIR" || fail "Failed to change dir"
        branch=$(git rev-parse --abbrev-ref HEAD) || fail "Failed to get branch"
        commit=$(git rev-parse --short HEAD) || fail "Failed to get commit"
        echo "Branch: ${branch} Commit: ${commit}"
        cd - >/dev/null || exit 1
    fi

    # Change to puppet dir
    cd "$TMP_PUPPET_DIR" || fail "Failed to change dir"
    # Hiera reads Vault directly from /root; never stage secrets in the checkout.
    [ -f ./hiera-linux.yaml ] || fail "Puppet repository is missing hiera-linux.yaml"

    # Get fqdn from facter
    FQDN=$(${FACTER_BIN} networking.fqdn)

    # Create a node definition for this host and write it to the manifests where puppet will pick it up
    cat <<EOF >manifests/nodes/nodes.pp
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
    PUPPET_OPTIONS=('--modulepath=./modules:./r10k_modules' '--hiera_config=./hiera-linux.yaml' '--logdest=console' '--color=false' '--detailed-exitcodes' './manifests/')
    export FACTER_PUPPETIZING=true

    # check for 'Error:' in the output; this catches errors even
    # when the puppet exit status is incorrect.
    TMP_LOG=$(mktemp "${BOOTSTRAP_DIR}/puppet-output.XXXXXX")
    [ -f "${TMP_LOG}" ] || fail "Failed to mktemp puppet log file"
    $PUPPET_BIN apply "${PUPPET_OPTIONS[@]}" 2>&1 | tee "${TMP_LOG}"
    retval=$?
    # just in case, if there were any errors logged, flag it as an error run
    if grep -q "^Error:" "${TMP_LOG}"; then
        retval=1
    fi

    rm "${TMP_LOG}"
    case $retval in
    0 | 2) return 0 ;;
    *) return 1 ;;
    esac
}

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

#
# main
#

# Parse options. Use of -l flags the script as non-interactive
while getopts ":h?l:" opt; do
    case "$opt" in
    h | \?)
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

# if we're not on linux, exit with warning
if [ "$(uname -s)" != "Linux" ]; then
    echo "This script is intended to run on Linux hosts only."
    exit 1
fi

[ "${EUID}" -eq 0 ] || fail "This bootstrap script must run as root."

# Keep downloads, package payloads, logs, and executable Puppet code inaccessible
# to task users. Preserve normal creation modes for Puppet-managed resources.
umask 022
BOOTSTRAP_DIR=$(mktemp -d /root/puppet-bootstrap.XXXXXX)
[ -d "${BOOTSTRAP_DIR}" ] || fail "Failed to mktemp bootstrap dir"
chmod 0700 "${BOOTSTRAP_DIR}"
trap 'rm -rf -- "${BOOTSTRAP_DIR}"' EXIT
trap 'exit 1' HUP INT TERM
TMP_PUPPET_DIR="${BOOTSTRAP_DIR}/code"

# check for /root/vault.yaml
if [ ! -f /root/vault.yaml ]; then
    echo "Missing /root/vault.yaml, this file is required for the bootstrap script to run."
    exit 1
fi

# determine ubuntu version so we can set NTP method appropriately
if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "This script requires /etc/os-release to determine the OS version."
    exit 1
fi

TEMP_DEB_PATH="${BOOTSTRAP_DIR}/bootstrap_temp.deb"
# noble, bionic, etc (VERSION_CODENAME) and 18.04, 24.04, etc (VERSION_ID)
# are sourced from /etc/os-release above

# puppet vars
#
# PKG_TO_INSTALL="puppet-agent"
# INSTALL_URL_BASE="https://apt.puppetlabs.com"
# INSTALL_URL_DEB="puppet8-release-noble.deb"
# INSTALL_URL_DEB="puppet7-release-bionic.deb"

# openvox vars
#
PKG_TO_INSTALL="openvox-agent"
INSTALL_URL_BASE="https://apt.voxpupuli.org"
INSTALL_URL_DEB="openvox8-release-ubuntu${VERSION_ID}.deb"

# we install openvox 8 on both, but NTP setup differs
if [ "$VERSION_ID" = "24.04" ]; then
    echo "Installing Openvox 8..."

    wget "${INSTALL_URL_BASE}/${INSTALL_URL_DEB}" -O "${TEMP_DEB_PATH}"
    # install puppet release deb for the version we've selected
    dpkg -i "${TEMP_DEB_PATH}"
    # update apt and install puppet-agent and ntp
    apt-get update
    # shellcheck disable=SC2090
    DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::='--force-confnew' remove -y puppet
    # shellcheck disable=SC2090
    DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::='--force-confnew' install -y "${PKG_TO_INSTALL}"

    if [ "${SKIP_NTP:-false}" != "true" ]; then
        # get clock synced. if clock is way off, run-puppet.sh will never finish
        #   it's git clone because the SSL cert will appear invalid.
        #
        # 24.04 uses timesyncd (on by default), see `systemctl status systemd-timesyncd`
        # place our config and restart the service
        mkdir -p /etc/systemd/timesyncd.conf.d
        echo -e "[Time]\nNTP=ntp.build.mozilla.org" >/etc/systemd/timesyncd.conf.d/mozilla.conf
        systemctl restart systemd-timesyncd
    fi
elif [ "$VERSION_ID" = "18.04" ]; then
    echo "Installing Openvox 8..."

    wget "${INSTALL_URL_BASE}/${INSTALL_URL_DEB}" -O "${TEMP_DEB_PATH}"
    # install puppet release deb for the version we've selected
    dpkg -i "${TEMP_DEB_PATH}"
    # update apt and install puppet-agent and ntp
    apt-get update
    # shellcheck disable=SC2090
    DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::='--force-confnew' remove -y puppet
    # shellcheck disable=SC2090
    DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::='--force-confnew' install -y "${PKG_TO_INSTALL}" ntp

    if [ "${SKIP_NTP:-false}" != "true" ]; then
        # get clock synced. if clock is way off, run-puppet.sh will never finish
        #   it's git clone because the SSL cert will appear invalid.
        /etc/init.d/ntp stop
        echo "server ntp.build.mozilla.org iburst" >/etc/ntp.conf # place barebones config
        ntpd -q -g                                                 # runs once and force allows huge skews
        /etc/init.d/ntp start
    fi
else
    echo "Unsupported Ubuntu version: $VERSION_ID. This script only supports Ubuntu 18.04 and 24.04."
    exit 1
fi

# Determine OSTYPE so we can set OS specific paths and alter logic if need be
case "${OSTYPE}" in
    darwin*) OS='darwin' ;;
    linux*)  OS='linux' ;;
    *)       fail "OS either not detected or not supported!" ;;
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
    ROLE=$(<"${ROLE_FILE}")
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

# Call the run_puppet function in a endless loop
while ! run_puppet; do
    echo "Puppet run failed; re-trying after 10m"
    sleep 600
done

# Remove the temp working puppet dir
cd / || fail "Failed to leave bootstrap checkout"
rm -rf -- "${BOOTSTRAP_DIR}"

# record the installation date (note that this won't appear anywhere on Darwin)
echo "System Installed: $(date)" >>/etc/issue

echo "Success. Rebooting..."

set +x
echo "   _____                                __"
echo "  / ___/__  _______________  __________/ /"
echo "  \__ \/ / / / ___/ ___/ _ \/ ___/ ___/ /"
echo " ___/ / /_/ / /__/ /__/  __(__  |__  )_/"
echo "/____/\__,_/\___/\___/\___/____/____(_)"

# Request an orderly reboot in the foreground. A background child can be
# killed when a systemd service's main bootstrap process exits. Keep errors
# visible and propagate a rejected reboot request to the caller.
exec /sbin/reboot
