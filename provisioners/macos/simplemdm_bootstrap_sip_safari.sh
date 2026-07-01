#!/bin/bash
# simplemdm_bootstrap_sip_safari.sh
#
# Operator-facing bootstrap script. NOT deployed by puppet — this file
# is the source-of-truth for the SimpleMDM script-job that runs on a
# fresh M4 Mac Mini at DEP enrollment time. Sibling to
# bootstrap_catalina.sh / bootstrap_mojave.sh in this directory.
#
# Upload procedure: copy this file's contents into the corresponding
# SimpleMDM Script (web UI → Scripts → "Dev - CC- Bootstrap" or
# equivalent), then bind it to the target Assignment Group.
#
# Run-once at enrollment time. Sets up the puppet override, clones
# ronin_puppet, and installs a one-shot LaunchDaemon that runs
# run-puppet.sh on every boot until the safari LaunchAgent flow
# completes — then the daemon self-removes.
#
# Prereqs delivered separately by MDM/operator:
#   - /var/root/vault.yaml          (still hand-dropped today)
#   - /etc/puppet_role              (MDM Custom Attribute)
#   - "Mozilla CI TCC Permissions"  PPPC mobileconfig (MDM Custom Profile)
#   - Xcode Command Line Tools      (DEP image — confirmed present on m4-118 post-EACS)
#   - admin GUI/VNC login           (load-bearing for Bootstrap Token custody)
#
# The script will block until `admin` holds a SecureToken before proceeding,
# so an out-of-order MDM kickoff won't strand BST on cltbld.

set -u
exec > /var/log/m4-bootstrap.log 2>&1
echo "=== m4-sip-safari-bootstrap start $(date) ==="

SENTINEL=/var/log/m4-bootstrap-complete
if [ -f "$SENTINEL" ]; then
  echo "$SENTINEL exists — bootstrap already complete, nothing to do."
  exit 0
fi

PUPPET_BRANCH=master
PUPPET_REPO=https://github.com/mozilla-platform-ops/ronin_puppet.git
REPO_DIR=/opt/puppet_environments/mozilla-platform-ops/ronin_puppet
LD_LABEL=com.mozilla.m4-bootstrap
LD_PATH=/Library/LaunchDaemons/${LD_LABEL}.plist
DRIVER=/usr/local/sbin/m4-bootstrap-driver.sh

#------------------------------------------------------------------------------
# 1. Wait for admin BST custody
#------------------------------------------------------------------------------
echo "Waiting for SecureToken on admin (admin must VNC-login first)..."
for _ in $(seq 1 180); do
  if /usr/sbin/sysadminctl -secureTokenStatus admin 2>&1 | grep -q 'ENABLED'; then
    echo "admin SecureToken ENABLED — BST custody good."
    break
  fi
  sleep 10
done
if ! /usr/sbin/sysadminctl -secureTokenStatus admin 2>&1 | grep -q 'ENABLED'; then
  echo "ERROR: admin does not hold a SecureToken after 30 min. Aborting."
  echo "Action: VNC in as admin and complete a console login, then re-run script."
  exit 1
fi

#------------------------------------------------------------------------------
# 2. Wait for prerequisites delivered out-of-band
#------------------------------------------------------------------------------
for need in /var/root/vault.yaml /etc/puppet_role; do
  echo "Waiting for $need..."
  for _ in $(seq 1 60); do
    [ -f "$need" ] && break
    sleep 10
  done
  if [ ! -f "$need" ]; then
    echo "ERROR: $need not delivered within 10 min. Aborting."
    exit 1
  fi
done
/bin/chmod 0600 /var/root/vault.yaml
/usr/sbin/chown root:wheel /var/root/vault.yaml
echo "puppet_role = $(cat /etc/puppet_role)"

#------------------------------------------------------------------------------
# 3. Ensure git works
#------------------------------------------------------------------------------
if ! /usr/bin/git --version >/dev/null 2>&1; then
  echo "git unavailable — attempting headless CLT install"
  if [ -d /Applications/Xcode.app ]; then
    /usr/bin/xcodebuild -license accept || true
  else
    TRIGGER=/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    /usr/bin/touch "$TRIGGER"
    LABEL=$(/usr/sbin/softwareupdate --list 2>/dev/null \
            | /usr/bin/awk '/\* (Command Line Tools|Label:.*Command Line)/{
                sub(/^\* /,""); sub(/^Label: /,""); print; exit }')
    [ -n "$LABEL" ] && /usr/sbin/softwareupdate -i "$LABEL" --verbose
    /bin/rm -f "$TRIGGER"
  fi
fi
/usr/bin/git --version || { echo "ERROR: git still unavailable. Aborting."; exit 1; }

#------------------------------------------------------------------------------
# 4. Drop ronin_settings (branch pin) + clone ronin_puppet
#------------------------------------------------------------------------------
/bin/mkdir -p /opt/puppet_environments
cat > /opt/puppet_environments/ronin_settings <<EOF
PUPPET_REPO=${PUPPET_REPO}
PUPPET_BRANCH=${PUPPET_BRANCH}
PUPPET_MAIL=rcurran@mozilla.com
EOF

if [ ! -d "${REPO_DIR}/.git" ]; then
  /bin/mkdir -p "$(/usr/bin/dirname "${REPO_DIR}")"
  /usr/bin/git clone --branch "${PUPPET_BRANCH}" "${PUPPET_REPO}" "${REPO_DIR}"
else
  ( cd "${REPO_DIR}" && /usr/bin/git fetch origin "${PUPPET_BRANCH}" \
      && /usr/bin/git reset --hard "origin/${PUPPET_BRANCH}" )
fi

#------------------------------------------------------------------------------
# 5. Set up ssh-to-localhost as root
#------------------------------------------------------------------------------
# Why: launchd-spawned processes live in the system domain and TCC denies user-DB
# writes from there even with PPPC FDA grants. Sshd-spawned shells live in the
# user session domain where the grants actually apply. So the driver routes
# run-puppet.sh through `ssh root@localhost`. macOS 15's default
# `PermitRootLogin without-password` allows key-auth, so no sshd_config edit needed.
SSH_DIR=/var/root/.ssh
SSH_KEY=${SSH_DIR}/bootstrap_id_ed25519
SSH_AUTH=${SSH_DIR}/authorized_keys
SSH_KEY_COMMENT=m4-bootstrap-sip-safari

/bin/mkdir -p "${SSH_DIR}"
/bin/chmod 0700 "${SSH_DIR}"
/usr/sbin/chown root:wheel "${SSH_DIR}"

if [ ! -f "${SSH_KEY}" ]; then
  /usr/bin/ssh-keygen -t ed25519 -N '' -f "${SSH_KEY}" -C "${SSH_KEY_COMMENT}"
fi
/bin/chmod 0600 "${SSH_KEY}" "${SSH_KEY}.pub"
/usr/sbin/chown root:wheel "${SSH_KEY}" "${SSH_KEY}.pub"

/usr/bin/touch "${SSH_AUTH}"
/bin/chmod 0600 "${SSH_AUTH}"
/usr/sbin/chown root:wheel "${SSH_AUTH}"
if ! /usr/bin/grep -qF "${SSH_KEY_COMMENT}" "${SSH_AUTH}"; then
  /bin/cat "${SSH_KEY}.pub" >> "${SSH_AUTH}"
fi

# Sanity check — ssh into ourselves should succeed without password
if ! /usr/bin/ssh -i "${SSH_KEY}" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o BatchMode=yes \
    -o LogLevel=ERROR \
    -o ConnectTimeout=10 \
    root@localhost true; then
  echo "ERROR: ssh root@localhost failed after key setup. Aborting."
  exit 1
fi
echo "ssh root@localhost key setup OK"

#------------------------------------------------------------------------------
# 6. Install the reboot-survivable driver LaunchDaemon
#------------------------------------------------------------------------------
/bin/mkdir -p /usr/local/sbin
cat > "${DRIVER}" <<'DRIVER_EOF'
#!/bin/bash
set -u
exec >> /var/log/m4-bootstrap-driver.log 2>&1
echo "=== driver tick $(date) ==="

SENTINEL=/var/log/m4-bootstrap-complete
SAFARI_SEM=/Users/cltbld/Library/Preferences/semaphore/safari-enable-remote-automation-has-run
TCC_SEM=/var/tmp/semaphore/safari-tcc-perms-applied
RUN_PUPPET=/usr/local/bin/run-puppet.sh
[ -x "${RUN_PUPPET}" ] || RUN_PUPPET=/opt/puppet_environments/mozilla-platform-ops/ronin_puppet/modules/macos_run_puppet/files/run-puppet.sh

SSH_KEY=/var/root/.ssh/bootstrap_id_ed25519
SSH_AUTH=/var/root/.ssh/authorized_keys
SSH_KEY_COMMENT=m4-bootstrap-sip-safari

check_done() {
  [ -f "${SAFARI_SEM}" ] && /usr/bin/grep -q '^1' "${SAFARI_SEM}" 2>/dev/null && [ -f "${TCC_SEM}" ]
}

# Wait for network — LaunchDaemon RunAtLoad can fire before DNS is up at boot.
for _ in $(seq 1 60); do
  /usr/bin/dscacheutil -q host -a name github.com 2>/dev/null | /usr/bin/grep -q ip_address && break
  echo "Waiting for DNS to github.com..."
  /bin/sleep 5
done

# Loop: invoke run-puppet.sh via ssh root@localhost so puppet runs in sshd's
# user-session domain (where TCC FDA grants for /bin/bash and /usr/bin/sqlite3
# actually take effect). The system-domain LaunchDaemon can't reach those grants
# directly even via `launchctl asuser 0`.
while ! check_done; do
  echo "Invoking ${RUN_PUPPET} via ssh root@localhost (user-domain TCC attribution)"
  /usr/bin/ssh -i "${SSH_KEY}" \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o BatchMode=yes \
      -o LogLevel=ERROR \
      -o ConnectTimeout=15 \
      root@localhost "${RUN_PUPPET}" \
      || echo "ssh run-puppet.sh exited non-zero, retrying after 30s"
  check_done && break
  /bin/sleep 30
done

echo "All bootstrap signals present. Writing sentinel + cleaning up."
# Kick worker-runner — the trigger semaphore that makes gw_checker/worker-runner
# actually start generic-worker. Without it the role sits idle in TC.
/bin/mkdir -p /var/tmp/semaphore
/usr/bin/touch /var/tmp/semaphore/run-buildbot
/usr/bin/touch "${SENTINEL}"
# Revoke the one-shot bootstrap ssh key now that we are done.
/bin/rm -f "${SSH_KEY}" "${SSH_KEY}.pub"
if [ -f "${SSH_AUTH}" ]; then
  /usr/bin/grep -v "${SSH_KEY_COMMENT}" "${SSH_AUTH}" > "${SSH_AUTH}.tmp" || true
  /bin/mv "${SSH_AUTH}.tmp" "${SSH_AUTH}"
  [ -s "${SSH_AUTH}" ] || /bin/rm -f "${SSH_AUTH}"
fi
# Remove plist + driver BEFORE bootout — bootout-self terminates the script.
/bin/rm -f /Library/LaunchDaemons/com.mozilla.m4-bootstrap.plist
/bin/rm -f /usr/local/sbin/m4-bootstrap-driver.sh
/bin/launchctl bootout system/com.mozilla.m4-bootstrap 2>/dev/null || true
exit 0
DRIVER_EOF
/bin/chmod 0755 "${DRIVER}"

cat > "${LD_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${LD_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${DRIVER}</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>/var/log/m4-bootstrap-driver.out</string>
  <key>StandardErrorPath</key><string>/var/log/m4-bootstrap-driver.err</string>
</dict>
</plist>
EOF
/bin/chmod 0644 "${LD_PATH}"
/usr/sbin/chown root:wheel "${LD_PATH}"

#------------------------------------------------------------------------------
# 6. Kick the driver immediately (and persist it for reboots)
#------------------------------------------------------------------------------
/bin/launchctl bootstrap system "${LD_PATH}" 2>/dev/null || /bin/launchctl load -w "${LD_PATH}"

echo "=== bootstrap script done; LaunchDaemon will drive run-puppet.sh ==="
echo "    Watch:  /var/log/m4-bootstrap-driver.log"
echo "    Done when: ${SENTINEL} exists"
exit 0
