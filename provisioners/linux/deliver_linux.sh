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

# 18.04
REMOTE_SSH_USER="root"
# 24.04
REMOTE_SSH_USER="relops"

# local files
BOOTSTRAP_FILE="bootstrap_linux.sh"
SECRETS_FILE="vault.yaml"
RONIN_SETTINGS="ronin_settings"

# remote files
ROLE_FILE_REMOTE="/etc/puppet_role"
SECRETS_FILE_REMOTE="/root/vault.yaml"
RONIN_SETTINGS_REMOTE="/etc/puppet/ronin_settings"
BOOTSTRAP_FILE_REMOTE="/tmp/bootstrap.sh"


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
if ssh "$REMOTE_SSH_USER"@"$THE_HOST" "test -e $ROLE_FILE_REMOTE"; then
  echo "ERROR: Host already has a puppet role set... Exiting!"
  exit 1
fi

# TODO: check that we're on 1804 also

# send stuff out

# remove an existing boostrap file
# shellcheck disable=SC2029
ssh "$REMOTE_SSH_USER"@"$THE_HOST" "rm -f $BOOTSTRAP_FILE_REMOTE"

# place bootsrap
# shellcheck disable=SC2029
scp "$BOOTSTRAP_FILE" "$REMOTE_SSH_USER"@"$THE_HOST":$BOOTSTRAP_FILE_REMOTE
# shellcheck disable=SC2029
ssh "$REMOTE_SSH_USER"@"$THE_HOST" "sudo chmod 755 $BOOTSTRAP_FILE_REMOTE"

# place secrets
# TODO: generate vault.yml with vault data
scp "$SECRETS_FILE" "$REMOTE_SSH_USER"@"$THE_HOST":/tmp/vault.yaml
# shellcheck disable=SC2029
ssh "$REMOTE_SSH_USER"@"$THE_HOST" "sudo mv /tmp/vault.yaml $SECRETS_FILE_REMOTE"
# shellcheck disable=SC2029
ssh "$REMOTE_SSH_USER"@"$THE_HOST" "sudo chmod 640 $SECRETS_FILE_REMOTE"

# finally, place role
# shellcheck disable=SC2029
ssh "$REMOTE_SSH_USER"@"$THE_HOST" "sudo sh -c 'echo $THE_ROLE > $ROLE_FILE_REMOTE'"

# if the ronin_settings file exists, copy it into place
RONIN_SETTINGS_PRESENT=0
if [ -e "$RONIN_SETTINGS" ]; then
  RONIN_SETTINGS_PRESENT=1
  wait_secs=10
  # source the file
  # shellcheck disable=SC1090
  source "$RONIN_SETTINGS"
  echo "Found ronin_settings file, copying to remote host in ${wait_secs} seconds..."
  sleep ${wait_secs}
  echo "Copying..."
  # shellcheck disable=SC2029
  scp "$RONIN_SETTINGS" "$REMOTE_SSH_USER"@"$THE_HOST":/tmp/ronin_settings
  # shellcheck disable=SC2029
  ssh "$REMOTE_SSH_USER"@"$THE_HOST" "sudo mv /tmp/ronin_settings $RONIN_SETTINGS_REMOTE"
  # shellcheck disable=SC2029
  ssh "$REMOTE_SSH_USER"@"$THE_HOST" "sudo chmod 640 $RONIN_SETTINGS_REMOTE"
fi

echo ""
echo "    ____       ___                          ____"
echo "   / __ \___  / (_)   _____  ________  ____/ / /"
echo "  / / / / _ \/ / / | / / _ \/ ___/ _ \/ __  / /"
echo " / /_/ /  __/ / /| |/ /  __/ /  /  __/ /_/ /_/"
echo "/_____/\___/_/_/ |___/\___/_/   \___/\__,_(_)"
echo ""
echo "You can now run one of the following:"
echo ""
# if ronin_settings_present == 0
if [ $RONIN_SETTINGS_PRESENT -eq 0 ]; then
  echo "  master:"
  echo "    ssh $REMOTE_SSH_USER@$THE_HOST
  echo "      sudo bash
  echo "      $BOOTSTRAP_FILE_REMOTE"
  echo ""
  echo "  branch:"
  echo "    ssh $REMOTE_SSH_USER@$THE_HOST"
  echo "      sudo bash"
  echo "        PUPPET_REPO='https://github.com/YOUR_ID/ronin_puppet.git' \\"
  echo "          PUPPET_BRANCH='YOUR_BRANCH' $BOOTSTRAP_FILE_REMOTE"
elif [ $RONIN_SETTINGS_PRESENT -eq 1 ]; then
  echo "  master:"
  echo "    ssh $REMOTE_SSH_USER@$THE_HOST $BOOTSTRAP_FILE_REMOTE"
  echo ""
  echo "  branch:"
  echo "    ssh $REMOTE_SSH_USER@$THE_HOST"
  echo "      sudo bash"
  echo "        PUPPET_REPO='$PUPPET_REPO' \\"
  echo "          PUPPET_BRANCH='$PUPPET_BRANCH' $BOOTSTRAP_FILE_REMOTE"
  echo ""
  echo "  * ronin-settings delivered, so even master (above) will eventually use the settings."
fi
