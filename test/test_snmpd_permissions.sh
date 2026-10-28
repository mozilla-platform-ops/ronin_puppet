#!/bin/bash
# Run as root in a disposable Ubuntu container with snmpd and snmp installed.
# Uses fixture communities only; no production service or secrets.
set -euo pipefail
cd "$(dirname "$0")/.."
useradd -m cltbld
config=/etc/snmp/snmpd.conf
sed 's/<%= @snmpd_ro_secret %>/fixture-before/' modules/linux_snmpd/templates/snmpd.conf.erb > "$config"
chown root:Debian-snmp "$config"
chmod 0640 "$config"
test "$(stat -c '%U:%G:%a' "$config")" = root:Debian-snmp:640
if runuser -u cltbld -- test -r "$config"; then
  echo 'Task user can read the community config' >&2
  exit 1
fi
runuser -u Debian-snmp -- test -r "$config"
daemon_pid=
cleanup() {
  if [ -n "$daemon_pid" ]; then
    kill "$daemon_pid" 2>/dev/null || true
    wait "$daemon_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT
start_daemon() {
  /usr/sbin/snmpd -Lo -u Debian-snmp -g Debian-snmp -I -smux,mteTrigger,mteTriggerConf -f > /tmp/snmpd-fixture.log 2>&1 &
  daemon_pid=$!
}
query() {
  snmpget -m '' -v2c -c "$1" -t 0.2 -r 0 -Oqv 127.0.0.1 .1.3.6.1.2.1.1.1.0 > /dev/null 2>&1
}
await_query() {
  for _ in {1..30}; do
    if query "$1"; then return; fi
    sleep 0.1
  done
  echo 'SNMP fixture query failed' >&2
  exit 1
}
start_daemon
await_query fixture-before
daemon_uid=$(id -u Debian-snmp)
test "$(awk '/^Uid:/ {print $2}' "/proc/$daemon_pid/status")" = "$daemon_uid"
# Rewrite in place to preserve Puppet's ownership/mode; reload must pick it up.
sed 's/fixture-before/fixture-after/' "$config" > /tmp/snmpd-next.conf
cat /tmp/snmpd-next.conf > "$config"
kill -HUP "$daemon_pid"
await_query fixture-after
if query fixture-before; then
  echo 'Reload retained the old community' >&2
  exit 1
fi
cleanup
daemon_pid=
start_daemon
await_query fixture-after
echo 'Passed: config permissions, task-user denial, daemon startup, SIGHUP reload, restart and SNMP queries'
