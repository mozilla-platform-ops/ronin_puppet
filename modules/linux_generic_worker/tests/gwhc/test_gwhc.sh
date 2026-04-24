#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/files/generic-worker-health-check"
FIX="$(cd "$(dirname "$0")" && pwd)/fixtures"

expect() {
    local fixture="$1" want_state="$2" want_exit="$3"
    local out
    set +e
    out=$(python3 "$SCRIPT" --replay "$FIX/$fixture" 2>&1)
    local got_exit=$?
    set -e
    if ! grep -q "^${want_state} " <<< "$out"; then
        echo "FAIL: $fixture — expected ${want_state} at start of output"
        echo "$out"
        exit 1
    fi
    if [[ "$got_exit" != "$want_exit" ]]; then
        echo "FAIL: $fixture — expected exit ${want_exit}, got ${got_exit}"
        exit 1
    fi
    echo "PASS: $fixture  (State: ${want_state}, exit ${got_exit})"
}

expect idle.json         IDLE         0
expect working.json      WORKING      0
expect provisioning.json PROVISIONING 0
expect recovering.json   RECOVERING   1
expect degraded.json     DEGRADED     1
expect down.json         DOWN         1

# round-trip: replay a fixture through --json, then replay that output
python3 "$SCRIPT" --replay "$FIX/idle.json" --json \
    | python3 "$SCRIPT" --replay - \
    | grep -q "^IDLE "
echo "PASS: round-trip idle.json --json | --replay -"

echo
echo "all gwhc summary tests passed"
