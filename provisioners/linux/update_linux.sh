#!/usr/bin/env bash

set -e
# set -x

#
# update_linux.sh
#   - updates vault.yaml
#   - fix clock
#   - can optionally set/update the role of a host
#

# local files
SECRETS_FILE="$HOME/vault.yaml"

# remote files
ROLE_FILE="/etc/puppet_role"

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

# check args

export THE_HOST="${1:-}"
export THE_ROLE="${2:-}"
export FORCE="${3:-}"

if [ -z "$THE_HOST" ]; then
  echo "ERROR: Please provide a host to bootstrap (like devicepool-0.relops.mozops.net)"
  exit 1
fi

if [ -n "$THE_ROLE" ] && ! [[ "$THE_ROLE" =~ ^[a-z][a-z0-9_]*$ ]]; then
  echo "ERROR: Role must start with a lowercase letter and contain only lowercase letters, digits, or underscores."
  exit 1
fi

# Ubuntu 22.04+ uses the configured NTP service through timedatectl. Wait
# for actual synchronization before transferring secrets or changing roles.
ssh "$THE_HOST" 'sudo /bin/sh -s' <<'SYNC_CLOCK'
set -eu
. /etc/os-release
if [ "$ID" = ubuntu ] && [ "${VERSION_ID%%.*}" -ge 22 ]; then
  synchronized=$(timedatectl show --property=NTPSynchronized --value)
  if [ "$synchronized" != yes ]; then
    timedatectl set-ntp true
  fi
  remaining=30
  while [ "$synchronized" != yes ]; do
    if [ "$remaining" -eq 0 ]; then
      echo 'ERROR: Clock did not synchronize within 60 seconds.' >&2
      exit 1
    fi
    sleep 2
    remaining=$((remaining - 1))
    synchronized=$(timedatectl show --property=NTPSynchronized --value)
  done
  echo 'INFO: Clock synchronized (timedatectl).'
else
  ntpd -q -g
fi
SYNC_CLOCK

# deliver secrets
install_vault "$THE_HOST"

# finally, place role
if [ -n "$THE_ROLE" ]; then
  # get the current role on the host
  # shellcheck disable=SC2029
  CURRENT_ROLE=$(ssh "$THE_HOST" "sudo cat $ROLE_FILE || true")
  # if current role differs and not in force mode
  if [ "$CURRENT_ROLE" != "$THE_ROLE" ]; then
    if [ -n "$FORCE" ] && [ "$FORCE" = "force" ]; then
      echo "INFO: Changing role from $CURRENT_ROLE to $THE_ROLE"
      printf '%s\n' "$THE_ROLE" | ssh "$THE_HOST" 'sudo /usr/bin/tee /etc/puppet_role >/dev/null'
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
