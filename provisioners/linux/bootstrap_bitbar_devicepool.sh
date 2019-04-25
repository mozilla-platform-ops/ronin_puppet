#!/usr/bin/env bash

set -e

PROVISION_REPO="https://github.com/mozilla-platform-ops/ronin_puppet.git"


## FUNCTIONS

# Download puppet repository
function get_puppet_repo {
    # clone or update repo
    if [ ! -d "${PUPPET_ENV}/production" ]; then
        # update
        ( cd "$PUPPET_ENV/production" && git pull --rebase )
    else
        # clone
        git clone "$PROVISION_REPO" "$PUPPET_ENV"
    fi

    # Change to puppet dir
    cd "${PUPPET_ENV}/production" || fail "Failed to change dir"
    chmod 777 .

    # Install R10k Modules
    $R10K_BIN puppetfile install -v || fail "Failed to install R10k modules"

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
  linux*)   OS='linux' ;;
  *)        fail "OS either not detected or not supported!" ;;
esac

# Linux and Darwin share some common paths
if [ $OS == "linux" ] || [ $OS == "darwin" ]; then
    ROLE_FILE='/etc/puppet_role'
    PUPPET_BIN='/opt/puppetlabs/bin/puppet'
    PUPPET_ENV='/etc/puppetlabs/code/environments'
    FACTER_BIN='/opt/puppetlabs/bin/facter'
    R10K_BIN='/opt/puppetlabs/bin/r10k'
fi

# all bitbar hosts have the same role
echo "bitbar_devicepool" > $ROLE_FILE

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

# install puppet
wget -P /var/tmp/ "http://apt.puppetlabs.com/puppet6-release-$(lsb_release -c -s).deb"
dpkg -i /var/tmp/*.deb
apt-get update -y && apt-get install -y puppet-agent
ln -s /opt/puppetlabs/bin/puppet /usr/bin/puppet
# install r10k
/opt/puppetlabs/puppet/bin/gem install r10k
# install other things
# TODO: move to pp file
apt-get install -y ruby vim git curl lvm2

# run puppet
run_puppet
