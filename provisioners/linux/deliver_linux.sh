#!/usr/bin/env bash

set -e
# set -x

# delivers bootstrap.sh, secrets.yml, and sets a role

# recommended ssh config entry
#
#   Host *.mdc1.mozilla.com *.mdc2.mozilla.com
#     ForwardAgent yes
#     ControlMaster auto
#     ControlPath ~/.ssh/sockets/%h-%r
#     ControlPersist yes
#

# local files
BOOTSTRAP_FILE="bootstrap_linux.sh"
SECRETS_FILE="vault.yaml"

# remote files
ROLE_FILE="/etc/puppet_role"


# ensure critical scripts/files exist

if [ ! -e "$BOOTSTRAP_FILE" ]; then
  echo "Couldn't find boostrap file ('$BOOTSTRAP_FILE')"
  exit 1
fi

if [ ! -e "$SECRETS_FILE" ]; then
  echo "Couldn't find secrets ('$SECRETS_FILE')"
  exit 1
fi


# check args

export THE_HOST="$1"
export THE_ROLE="$2"

if [ -z "$THE_HOST" ]; then
  echo "ERROR: Please provide a host to bootstrap (like devicepool-0.relops.mozops.net)"
  exit 1
fi

if [ -z "$THE_ROLE" ]; then
  echo "ERROR: Please provide the role to assign to the host (like gecko_t_linux_talos)"
  exit 1
fi


# check host

# cleanup ssh key, it will be new after kickstarting
ssh-keygen -R "${THE_HOST}"
# readd to avoid prompts
ssh-keyscan -H "${THE_HOST}" >> ~/.ssh/known_hosts

# ensure we're not bootstrapping a host that's already been done
# shellcheck disable=SC2029
if ssh root@"$THE_HOST" "test -e $ROLE_FILE"; then
  echo "ERROR: Host already has a puppet role set... Exiting!"
  exit 1
fi

# TODO: check that we're on 1804 also


# send stuff out

# place bootsrap
scp "$BOOTSTRAP_FILE" root@"$THE_HOST":/root/bootstrap.sh
ssh root@"$THE_HOST" chmod 755 /root/bootstrap.sh

# place secrets
# TODO: generate vault.yml with vault data
scp "$SECRETS_FILE" root@"$THE_HOST":/root/vault.yaml
ssh root@"$THE_HOST" chmod 640 /root/vault.yaml

# finally, place role
# shellcheck disable=SC2029
ssh root@"$THE_HOST" "echo $THE_ROLE > $ROLE_FILE"

echo ""
echo "    ____       ___                          ____"
echo "   / __ \___  / (_)   _____  ________  ____/ / /"
echo "  / / / / _ \/ / / | / / _ \/ ___/ _ \/ __  / /"
echo " / /_/ /  __/ / /| |/ /  __/ /  /  __/ /_/ /_/"
echo "/_____/\___/_/_/ |___/\___/_/   \___/\__,_(_)"
echo ""
echo "now run one of the following:"
echo ""
echo "  master:"
echo "    ssh root@$THE_HOST /root/bootstrap.sh"
echo ""
echo "  branch:"
echo "    ssh root@$THE_HOST \\"
echo "      PUPPET_REPO='https://github.com/YOUR_ID/ronin_puppet.git' \\"
echo "      PUPPET_BRANCH='YOUR_BRANCH' /root/bootstrap.sh"
