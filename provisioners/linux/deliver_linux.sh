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

# Detect which SSH user works (try relops first, then root)
# Retries for up to ~10 minutes to handle hosts where auth isn't ready immediately
detect_ssh_user() {
  local host="$1"
  local max_attempts=60
  for attempt in $(seq 1 "$max_attempts"); do
    for user in "relops" "root"; do
      if ssh -o ConnectTimeout=5 -o BatchMode=yes -q "$user"@"$host" exit 2>/dev/null; then
        echo "$user"
        return 0
      fi
    done
    if [ "$attempt" -lt "$max_attempts" ]; then
      printf '.' >&2
      sleep 10
    fi
  done
  echo ""
  return 0
}

REMOTE_SSH_USER=""

# local files
BOOTSTRAP_FILE="bootstrap_linux.sh"
SECRETS_FILE="$HOME/vault.yaml"
RONIN_SETTINGS="ronin_settings"

# remote files
ROLE_FILE_REMOTE="/etc/puppet_role"
RONIN_SETTINGS_REMOTE="/etc/puppet/ronin_settings"

install_vault() {
  local ssh_target="$1"

  # Stream directly to a root-owned temporary file, then atomically replace the
  # active Vault file. Never stage secrets in a task-writable directory.
  # shellcheck disable=SC2029 # The quoted script intentionally runs on the remote host.
  ssh "$ssh_target" "sudo /bin/sh -c 'set -eu
umask 077
vault_tmp=\$(mktemp /root/.vault.yaml.XXXXXX)
cleanup() { rm -f -- \"\$vault_tmp\"; }
trap cleanup EXIT HUP INT TERM
cat > \"\$vault_tmp\"
chown root:root \"\$vault_tmp\"
chmod 0640 \"\$vault_tmp\"
mv -f -- \"\$vault_tmp\" /root/vault.yaml
trap - EXIT HUP INT TERM
'" < "$SECRETS_FILE"
}
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

export THE_HOST="${1:-}"
export THE_ROLE="${2:-}"

if [ -z "$THE_HOST" ]; then
  echo "ERROR: Please provide a host to bootstrap (like devicepool-0.relops.mozops.net)"
  exit 1
fi

if [ -z "$THE_ROLE" ]; then
  echo "ERROR: Please provide the role to assign to the host (like gecko_t_linux_talos)"
  exit 1
fi

if ! [[ "$THE_ROLE" =~ ^[a-z][a-z0-9_]*$ ]]; then
  echo "ERROR: Role must start with a lowercase letter and contain only lowercase letters, digits, or underscores."
  exit 1
fi


# check host

# cleanup ssh key, it will be new after kickstarting
ssh-keygen -R "${THE_HOST}" || true
# readd to avoid prompts; retry until SSH daemon is ready
echo "Waiting for SSH on ${THE_HOST}..."
for _i in $(seq 1 60); do
  result=$(ssh-keyscan -H "${THE_HOST}" 2>/dev/null)
  if [ -n "$result" ]; then
    echo "$result" >> ~/.ssh/known_hosts
    break
  fi
  printf '.'
  sleep 10
done

# detect which SSH user works
echo "Detecting SSH user for ${THE_HOST}..."
REMOTE_SSH_USER=$(detect_ssh_user "${THE_HOST}")
if [ -z "$REMOTE_SSH_USER" ]; then
  echo "ERROR: Could not connect to host using root or relops users"
  exit 1
fi
echo "Using SSH user: $REMOTE_SSH_USER"

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
install_vault "$REMOTE_SSH_USER@$THE_HOST"

# finally, place role
printf '%s\n' "$THE_ROLE" | ssh "$REMOTE_SSH_USER"@"$THE_HOST" 'sudo /usr/bin/tee /etc/puppet_role >/dev/null'

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
  echo "    ssh $REMOTE_SSH_USER@$THE_HOST sudo bash $BOOTSTRAP_FILE_REMOTE"
  echo ""
  echo "  branch:"
  echo "    ssh $REMOTE_SSH_USER@$THE_HOST"
  echo "      sudo bash"
  echo "        PUPPET_REPO='https://github.com/YOUR_ID/ronin_puppet.git' \\"
  echo "        PUPPET_BRANCH='YOUR_BRANCH' $BOOTSTRAP_FILE_REMOTE"
elif [ $RONIN_SETTINGS_PRESENT -eq 1 ]; then
  echo "  master:"
  echo "    ssh $REMOTE_SSH_USER@$THE_HOST sudo bash $BOOTSTRAP_FILE_REMOTE"
  echo ""
  echo "  branch (uses the branch the ronin_settings file specifies):"
  echo "    ssh $REMOTE_SSH_USER@$THE_HOST"
  echo "      sudo bash"
  echo "        PUPPET_REPO='$PUPPET_REPO' \\"
  echo "        PUPPET_BRANCH='$PUPPET_BRANCH' $BOOTSTRAP_FILE_REMOTE"
  echo ""
  echo "NOTE: A ronin-settings file was delivered ($RONIN_SETTINGS_REMOTE), so even if"
  echo "the 'master' commands are used the host will use the ronin-settings file on the"
  echo "next run-puppet.sh run."
fi
