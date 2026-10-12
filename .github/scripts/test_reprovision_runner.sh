#!/usr/bin/env bash
#
# Behavioural tests for the reprovision_runner module's templates. The runner role
# is not in the kitchen matrix, so nothing else in CI applies this module.
#
# Renders the real EPP templates with `puppet epp render`, then:
#   - runs the self-update script against stand-in processes, with run-puppet.sh
#     and the lock path swapped for test doubles, to check it skips while a job
#     is in flight, runs when idle, honours its lock, and bounds a hung apply;
#   - checks the LaunchDaemon plists: ExitTimeOut on the runner only (so SIGTERM
#     can drain in-flight jobs), and the self-update daemon's schedule.

set -eu -o pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
templates="$repo_root/modules/reprovision_runner/templates"
work=$(mktemp -d "${TMPDIR:-/tmp}/test-reprovision-runner.XXXXXX")
cleanup() {
  jobs -p | xargs -r kill 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

failures=0
fail() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }
pass() { echo "ok: $*"; }

render() {  # render <template> <values-hash> <output>
  puppet epp render "$templates/$1" --values "$2" > "$3"
}

plist_value() {  # plist_value <file> <key>  -> value, or "absent"
  python3 - "$1" "$2" <<'PY'
import plistlib, sys
with open(sys.argv[1], "rb") as f:
    d = plistlib.load(f)
print(d.get(sys.argv[2], "absent"))
PY
}

# ---------------------------------------------------------------------------
# self-update script
# ---------------------------------------------------------------------------

fake_runner="$work/fake-runner.sh"
printf 'sleep 300 & wait\n' > "$fake_runner"
marker="$work/puppet-ran"

# Two renders: a distinctive max_seconds (37) for the normal paths, so a watchdog
# sleep left behind is identifiable, and a short one (2) for the hung-apply case.
render reprovision-runner-self-update.sh.epp \
  "{runner_bin => '$fake_runner', max_seconds => 37}" "$work/self-update.rendered.sh"
render reprovision-runner-self-update.sh.epp \
  "{runner_bin => '$fake_runner', max_seconds => 2}" "$work/self-update-short.rendered.sh"
bash -n "$work/self-update.rendered.sh"

# Test doubles: the lock lives in the work dir, and run-puppet.sh is replaced by a
# stub whose behaviour is picked per case. Everything else is the rendered script.
cat > "$work/run-puppet-stub.sh" <<EOF
#!/usr/bin/env bash
touch "$marker"
[ "\${STUB_MODE:-ok}" = hang ] && exec sleep 40
exit 0
EOF
chmod +x "$work/run-puppet-stub.sh"
for variant in self-update self-update-short; do
  sed -e "s|^LOCK_DIR=.*|LOCK_DIR=$work/lock|" \
      -e "s|/usr/local/bin/run-puppet.sh|$work/run-puppet-stub.sh|" \
      "$work/$variant.rendered.sh" > "$work/$variant.sh"
  grep -q "$work/run-puppet-stub.sh" "$work/$variant.sh" || fail "could not substitute run-puppet.sh in $variant"
done

# Bounded by the test itself, so a regression fails instead of hanging CI.
run_self_update() {  # run_self_update [STUB_MODE] [variant] -> output in $out
  local pid tenths=0
  rm -f "$marker" "$work/out"
  STUB_MODE=${1:-ok} bash "$work/${2:-self-update}.sh" > "$work/out" 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if (( tenths >= 600 )); then
      { pkill -P "$pid"; kill "$pid"; } 2>/dev/null || true
      echo "TEST TIMEOUT after 60s" >> "$work/out"
      break
    fi
    sleep 0.1
    tenths=$((tenths + 1))
  done
  wait "$pid" 2>/dev/null || true
  out=$(< "$work/out")
}

# Busy: the stand-in runner has a child process, i.e. a job in flight.
bash "$fake_runner" 2>/dev/null & busy_runner=$!
for _ in $(seq 1 50); do pgrep -P "$busy_runner" >/dev/null && break; sleep 0.1; done
run_self_update
if [[ $out == *"job in flight"* && ! -e $marker ]]; then
  pass "skips while a job is in flight"
else
  fail "busy runner: expected a skip without running puppet; got: $out"
fi
{ pkill -P "$busy_runner"; kill "$busy_runner"; wait "$busy_runner"; } 2>/dev/null || true

# Idle: the stand-in runner exists but has no children.
bash -c "exec -a '$fake_runner' sleep 300" & idle_runner=$!
sleep 0.3
run_self_update
if [[ $out == *"runner idle; running puppet"* && $out == *"exited 0"* && -e $marker ]]; then
  pass "runs puppet when the runner is idle"
else
  fail "idle runner: expected puppet to run; got: $out"
fi
# The watchdog must be torn down with its sleep, or every hourly run leaves a
# `sleep <max_seconds>` behind.
if pgrep -fx "/bin/sleep 37" >/dev/null; then
  fail "watchdog sleep left running after a normal run"
  pkill -fx "/bin/sleep 37" || true
else
  pass "watchdog fully torn down after a normal run"
fi
# Reaping the watchdog after a normal run must not print a job-kill notice into
# self-update.log on every hourly run.
if [[ $out == *"Terminated"* ]]; then
  fail "watchdog kill notice leaked into a normal run's log: $out"
else
  pass "no watchdog kill notice after a normal run"
fi

# Lock held by a previous run: skip, and leave that run's lock alone.
mkdir "$work/lock"
run_self_update
if [[ $out == *"previous update still running"* && ! -e $marker && -d $work/lock ]]; then
  pass "skips while a previous update holds the lock"
else
  fail "held lock: expected a skip; got: $out"
fi
rmdir "$work/lock"

# A stale lock (older than 2 x max_seconds, i.e. left by a killed run) is cleared,
# or one crash would block every later update until the next boot.
mkdir "$work/lock"
python3 -c 'import os, sys, time; t = time.time() - 3600; os.utime(sys.argv[1], (t, t))' "$work/lock"
run_self_update
if [[ $out == *"removing stale lock"* && $out == *"runner idle; running puppet"* && -e $marker && ! -d $work/lock ]]; then
  pass "clears a stale lock and proceeds"
else
  fail "stale lock: expected it cleared and puppet run; got: $out"
fi

# A hung apply is stopped at max_seconds (2 here) rather than holding the lock forever.
start=$(date +%s)
run_self_update hang self-update-short
elapsed=$(( $(date +%s) - start ))
if [[ $out == *"exceeded 2s"* && $out == *"exited 143"* ]] && (( elapsed < 30 )) && [[ ! -d $work/lock ]]; then
  pass "bounds a hung run-puppet.sh and releases the lock (${elapsed}s)"
else
  fail "hung apply: expected the watchdog to stop it; ${elapsed}s, got: $out"
fi

{ kill "$idle_runner"; wait "$idle_runner"; } 2>/dev/null || true

# ---------------------------------------------------------------------------
# LaunchDaemon plists
# ---------------------------------------------------------------------------

common="label => 'com.mozilla.x', wrapper => '/usr/local/bin/w.sh', log_dir => '/var/log/reprovision-runner'"

render com.mozilla.reprovision-runner.plist.epp \
  "{$common, log_name => 'runner', exit_timeout => 3600}" "$work/runner.plist"
if [[ $(plist_value "$work/runner.plist" ExitTimeOut) == 3600 ]]; then
  pass "runner plist carries ExitTimeOut"
else
  fail "runner plist ExitTimeOut: $(plist_value "$work/runner.plist" ExitTimeOut)"
fi

render com.mozilla.reprovision-runner.plist.epp \
  "{$common, log_name => 'screen-agent'}" "$work/agent.plist"
if [[ $(plist_value "$work/agent.plist" ExitTimeOut) == absent ]]; then
  pass "agent plists render without ExitTimeOut"
else
  fail "agent plist unexpectedly has ExitTimeOut"
fi
[[ $(plist_value "$work/agent.plist" KeepAlive) == True ]] \
  || fail "agent plist lost KeepAlive"

render com.mozilla.reprovision-runner-self-update.plist.epp \
  "{label => 'com.mozilla.reprovision-runner-self-update', script => '/usr/local/bin/s.sh', interval => 3600, log_dir => '/var/log/reprovision-runner'}" \
  "$work/self-update.plist"
if [[ $(plist_value "$work/self-update.plist" StartInterval) == 3600 &&
      $(plist_value "$work/self-update.plist" RunAtLoad) == False &&
      $(plist_value "$work/self-update.plist" KeepAlive) == absent ]]; then
  pass "self-update plist: StartInterval, not RunAtLoad, not KeepAlive"
else
  fail "self-update plist schedule is wrong"
fi

if (( failures > 0 )); then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "all reprovision_runner template tests passed"
