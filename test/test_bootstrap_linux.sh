#!/usr/bin/env bash
# Exercise checkout preparation and apply retries without root or network access.
# shellcheck disable=SC1090,SC2034
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
script="${repo_root}/provisioners/linux/bootstrap_linux.sh"
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/bootstrap-linux-test.XXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT

source <(sed -n '/^function get_puppet_repo {/,/^# If something fails hard/p' "$script" | sed '$d')
fail() { printf '%s\n' "$*" >&2; exit 1; }

fixture="${test_dir}/fixture"
mkdir -p "$fixture/manifests/nodes" "$fixture/modules" "$fixture/r10k_modules"
cp "${repo_root}/hiera-linux.yaml" "$fixture/hiera-linux.yaml"
tar -czf "${test_dir}/fixture.tar.gz" -C "$test_dir" fixture

curl() {
    cp "${test_dir}/fixture.tar.gz" "$4"
    printf '200'
}
git() {
    case "$1" in
        clone) cp -R "$fixture/." "$TMP_PUPPET_DIR/" ;;
        rev-parse) printf 'test-revision\n' ;;
        *) fail "Unexpected git command: $*" ;;
    esac
}
fake_facter() { printf 'test.example.com\n'; }
fake_puppet() {
    [[ "$*" == *'--hiera_config=./hiera-linux.yaml'* ]] || fail 'Wrong Hiera config'
    [ ! -e data/secrets ] || fail 'Vault secrets staged in checkout'
    [ ! -e stale.pp ] || fail 'Retry reused previous checkout contents'
    [ -f manifests/nodes/nodes.pp ] || fail 'Missing generated node definition'
    if [ "$apply_result" = failure ]; then
        printf 'Error: simulated apply failure\n'
    else
        printf 'Apply succeeded\n'
    fi
}

FACTER_BIN=fake_facter
PUPPET_BIN=fake_puppet
PUPPET_REPO=https://github.com/mozilla-platform-ops/ronin_puppet.git
PUPPET_REPO_BUNDLE=https://example.invalid/fixture.tar.gz
ROLE=gecko_t_linux_talos

for PUPPET_BRANCH in master test-branch; do
    BOOTSTRAP_DIR=$(mktemp -d "${test_dir}/bootstrap.XXXXXX")
    TMP_PUPPET_DIR="${BOOTSTRAP_DIR}/code"
    apply_result=failure
    if run_puppet >"${test_dir}/output" 2>&1; then
        fail 'Failed apply reported success'
    fi
    touch "${TMP_PUPPET_DIR}/stale.pp"
    apply_result=success
    run_puppet >"${test_dir}/output" 2>&1 || fail 'Retry failed'
    [ -z "$(find "$BOOTSTRAP_DIR" -name 'puppet-output.*' -print)" ] || fail 'Apply log was not cleaned up'
    printf 'Passed: %s checkout and apply retry\n' "$PUPPET_BRANCH"
done

# An older checkout must not silently fall back to staging Vault in the tree.
rm "$fixture/hiera-linux.yaml"
if (get_puppet_repo) >"${test_dir}/output" 2>&1; then
    fail 'Checkout without Linux Hiera config was accepted'
fi
grep -q 'missing hiera-linux.yaml' "${test_dir}/output" || fail 'Unexpected checkout rejection'
printf 'Passed: checkout without Linux Hiera config is rejected\n'

# Exercise the final handoff with a delayed fake reboot. A background command
# would return before completion and hide its nonzero exit status.
cat > "${test_dir}/reboot" <<'REBOOT'
#!/bin/bash
[ "$#" = 0 ] || exit 99
sleep 0.1
touch "$REBOOT_FINISHED"
exit "$REBOOT_RESULT"
REBOOT
chmod +x "${test_dir}/reboot"
for expected in 0 23; do
    export REBOOT_FINISHED="${test_dir}/reboot-finished-${expected}"
    export REBOOT_RESULT="$expected"
    python3 - "$script" "${test_dir}/reboot" "${test_dir}/handoff.sh" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
handoff = source[source.rindex('\nset +x\n'):]
assert handoff.count('exec /sbin/reboot') == 1
Path(sys.argv[3]).write_text(handoff.replace('exec /sbin/reboot', 'exec "' + sys.argv[2] + '"'))
PY
    actual=0
    bash "${test_dir}/handoff.sh" >"${test_dir}/reboot-output" 2>&1 || actual=$?
    [ "$actual" = "$expected" ] || fail 'Reboot result was hidden'
    [ -f "$REBOOT_FINISHED" ] || fail 'Bootstrap exited before reboot command finished'
done
printf 'Passed: orderly reboot handoff waits and propagates failures\n'
