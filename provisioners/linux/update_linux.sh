#!/usr/bin/env bash

set -e
# set -x

# local files
# BOOTSTRAP_FILE="bootstrap_linux.sh"
SECRETS_FILE="vault.yaml"

# remote files
ROLE_FILE="/etc/puppet_role"

# check args

export THE_HOST="$1"
export THE_ROLE="$2"
export FORCE="$3"

if [ -z "$THE_HOST" ]; then
  echo "ERROR: Please provide a host to bootstrap (like devicepool-0.relops.mozops.net)"
  exit 1
fi

# if [ -z "$THE_ROLE" ]; then
#   echo "ERROR: Please provide the role to assign to the host (like gecko_t_linux_talos)"
#   exit 1
# fi

# echo "WARNING: This command will overwrite a host's role!"
# if [ -n "$FORCE" ] && [ "$FORCE" = "force" ]; then
#     # pass
#     echo "INFO: force argument given, continuing"
# else
#     echo "ERROR: You must provide a third argument FORCE argument set to 'force' to continue."
#     exit 1
# fi

# do stuff

# set -x

# # sync clock
# ssh "$THE_HOST" sudo /etc/init.d/ntp stop
# # runs once and force allows huge skews
# ssh "$THE_HOST" sudo ntpd -q -g
# ssh "$THE_HOST" sudo /etc/init.d/ntp start

# deliver secrets
scp "$SECRETS_FILE" "$THE_HOST":/tmp/vault.yaml
ssh "$THE_HOST" sudo mv /tmp/vault.yaml /root/vault.yaml
ssh "$THE_HOST" sudo chmod 640 /root/vault.yaml

# finally, place role

if [ -n "$THE_ROLE" ]; then
  # get the current role on the host
  # shellcheck disable=SC2029
  CURRENT_ROLE=$(ssh "$THE_HOST" "sudo cat $ROLE_FILE || true")
  # if current role differs and not in force mode
  if [ "$CURRENT_ROLE" != "$THE_ROLE" ]; then
    if [ -n "$FORCE" ] && [ "$FORCE" = "force" ]; then
      echo "INFO: Changing role from $CURRENT_ROLE to $THE_ROLE"
        # shellcheck disable=SC2029
      ssh "$THE_HOST" "sudo bash -c 'echo $THE_ROLE > $ROLE_FILE'"
    else
      echo "ERROR: Role change requested but not in force mode."
      exit 1
    fi
  else
    echo "INFO: Role is already set to $THE_ROLE, skipping role assignment."
  fi
else
  echo "INFO: No role specified, skipping role assignment."
fi
