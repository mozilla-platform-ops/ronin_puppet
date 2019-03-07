#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Purpose: bootstrap a posix host from post install (or image) to a complete puppet run
# This script it intend to be run either run by hand or from an init system after a host has been
# provisioned or re-imaged

# Prerequisites:
#  * curl
#  * tar w/gzip
#  * Puppet agent 6.x.x
#  * R10k 3.x.x


# TODO:
# pull and generate vault secrets to yaml (or json).  Block if secrets don't exist, soft fail if cached

# URL of puppet repo to download
# TODO: change this url to track master on the moz platform ops org relop
PUPPET_REPO='https://github.com/dividehex/ronin_puppet/archive/bootstrap.tar.gz'

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
            echo "Usage: ./bootstrap_posix.sh -h               - Show help"
            echo "       ./bootstrap_posix.sh -l /path/logfile - Log output to file"
            echo "       ./bootstrap_posix.sh                  - Interactive mode"
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
    PUPPET_BIN='/opt/puppetlabs/bin/puppet'
    FACTER_BIN='/opt/puppetlabs/bin/facter'
    R10K_BIN='/opt/puppetlabs/bin/r10k'
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

if [ ! -x "${R10K_BIN}" ]; then
    fail "${R10K_BIN} is missing or not executable"
fi

# Create a temp dir for executing puppet
TMP_PUPPET_DIR=$(mktemp -d -t puppet_working)
[ -d "${TMP_PUPPET_DIR}" ] || fail "Failed to mktemp puppet working dir"

# Download puppet repository and extract
function get_puppet_repo {
    TMP_DL_DIR=$(mktemp -d -t puppet_download)
    [ -d "${TMP_DL_DIR}" ] || fail "Failed to mktemp download dir"

    # Download the puppet repo tarball directly from github
    # We don't use git because some oses don't have git installed by default
    # In the future, we may publish master branch to s3 or some other highly available service since
    # Github has rate limits on downloads.
    curl -sL $PUPPET_REPO -o "${TMP_DL_DIR}/puppet.tar.gz" || fail "Failed to download puppet repo tar.gz"
    # Extract the puppet repo tarball
    tar -zxf "${TMP_DL_DIR}/puppet.tar.gz" --strip 1 -C "${TMP_PUPPET_DIR}" || fail "Failed to extract puppet tar.gz"
    # Clean up the download dir
    rm -rf "${TMP_DL_DIR}"

    # Change to puppet dir
    cd "$TMP_PUPPET_DIR" || fail "Failed to change dir"

    # Install R10k Modules
    $R10K_BIN puppetfile install || fail "Failed to install R10k modules"

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
    PUPPET_OPTIONS=('--modulepath=./modules:./r10k_modules' '--hiera_config=./hiera.yaml' '--logdest=console' '--color=false' '--detailed-exitcodes' './manifests/' '--noop')
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
    Darwin)
        rm /Library/LaunchDaemons/org.mozilla.boostrap_posix.plist*
        ;;
esac

# Remove the temp working puppet dir
rm -rf "$TMP_PUPPET_DIR"

# record the installation date (note that this won't appear anywhere on Darwin)
echo "System Installed: $(date)" >> /etc/issue

exit 0
