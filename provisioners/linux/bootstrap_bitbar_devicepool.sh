#!/usr/bin/env bash

set -e
set -x

ROLE="bitbar_devicepool"
PUPPET_REPO="https://github.com/mozilla-platform-ops/ronin_puppet.git"
PUPPET_BRANCH="master"

PUPPET_BIN='/opt/puppetlabs/bin/puppet'
PUPPET_ENV_DIR='/etc/puppetlabs/environments'
FACTER_BIN='/opt/puppetlabs/bin/facter'
R10K_BIN='/opt/puppetlabs/puppet/bin/r10k'
R10K_DIR="/etc/puppetlabs/environments/production/r10k_modules"
ROLE_FILE='/etc/puppet_role'
PUPPET_REPO_PATH="$PUPPET_ENV_DIR/production"



## FUNCTIONS

function fail {
    echo "${@}"
    exit 1
}

function update_puppet {
    mkdir -p "$PUPPET_REPO_PATH"
    cd "$PUPPET_REPO_PATH"

    # Initialize working dir if dir is not a git repo
    if [ ! -d .git ]; then
        git init || return 1
        git remote add origin "${PUPPET_REPO}" || return 1
    fi

    # Fetch and checkout production branch
    git fetch --all --prune || return 1
    git checkout --force origin/${PUPPET_BRANCH} || return 1

    # Purge modules no longer managed by Puppetfile
    R10K_PURGE_OPTIONS=("--moduledir=${R10K_DIR}" '-v')
    $R10K_BIN puppetfile purge "${R10K_PURGE_OPTIONS[@]}"

    # Install r10k modules
    R10K_INSTALL_OPTIONS=("--moduledir=${R10K_DIR}" '--force' '-v')
    $R10K_BIN puppetfile install "${R10K_INSTALL_OPTIONS[@]}"

    FQDN=$(${FACTER_BIN} networking.fqdn)

    cat <<EOF > "${PUPPET_REPO_PATH}/manifests/nodes/nodes.pp"
    node '${FQDN}' {
        include ::roles_profiles::roles::${ROLE}
    }
EOF

    return 0
}

# Run puppet and return non-zero if errors are present
function run_puppet {
    echo "Running puppet apply"

    cd $PUPPET_REPO_PATH
    # this includes:
    # FACTER_PUPPETIZING so that the manifests know this is a first run of puppet
    # TODO: send logs to syslog? send a puppet report to puppetdb?
    PUPPET_OPTIONS=('--modulepath=./modules:./r10k_modules' '--hiera_config=./hiera.yaml' '--logdest=console' '--color=false' '--detailed-exitcodes' './manifests/')
    # PUPPET_OPTIONS=('--modulepath=./modules:./r10k_modules' '--debug' '--hiera_config=./hiera.yaml' '--logdest=console' '--color=false' '--detailed-exitcodes' './manifests/')

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


## MAIN

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

# Determine OSTYPE so we can set OS specific paths and alter logic if need be
case "${OSTYPE}" in
  linux*)   ;;
  *)        fail "OS either not detected or not supported!" ;;
esac

# guard against running on hosts with other roles
if [ -e "$ROLE_FILE" ]; then
    # this is not a first run or the role is preconfigured
    if grep -Fxq "$ROLE" "$ROLE_FILE"; then
        # ok to continue
        echo "Detected required role '$ROLE' in role file at '$ROLE_FILE'."
    else
        echo "ERROR: This host doesn't have the required role '$ROLE' in the role file at '$ROLE_FILE'!"
        exit 1
    fi
else
    # first run
    # all bitbar_devicepool hosts have the same role
    echo "First run detected, setting role file '$ROLE_FILE' to role '$ROLE'."
    echo "$ROLE" > $ROLE_FILE
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

# install puppet
wget -P /var/tmp/ "http://apt.puppetlabs.com/puppet6-release-$(lsb_release -c -s).deb"
dpkg -i /var/tmp/*.deb
apt-get update -y && apt-get install -y puppet-agent
ln -sf /opt/puppetlabs/bin/puppet /usr/bin/puppet
# install r10k
/opt/puppetlabs/puppet/bin/gem install r10k

# get the repo
update_puppet

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

# run puppet
run_puppet
