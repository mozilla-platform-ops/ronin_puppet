#!/usr/bin/env bash
# Exercise the Linux wrapper against disposable local repositories, without SSH.
# ShellCheck cannot follow functions extracted from the ERB template.
# shellcheck disable=SC1090,SC2034
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
template="${repo_root}/modules/puppet/templates/puppet-ubuntu-run-puppet.sh.erb"
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/run-puppet-git-recovery.XXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT

# Keep the fixtures independent of user settings and prohibit network protocols.
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_ALLOW_PROTOCOL=file
for function_name in recover_empty_remote_refs archive_git_gc_log; do
    source <(sed -n "/^function ${function_name} {/,/^}/p" "$template")
done
# update_puppet contains a heredoc with a column-zero closing brace.
source <(sed -n '/^function update_puppet {/,/^function recover_interrupted_dpkg {/p' "$template" | sed '$d')

require_secure_working_dir() { :; }
remove_staged_vault_secrets() { :; }
fetch_puppet_remote() {
    printf 'fetch\n' >> "$events"
    command git fetch --prune origin
}
configure_public_anonymous_auth() { return 1; }
reinit_working_dir() {
    printf 'Unexpected checkout reinitialization\n' >&2
    return 1
}

git init --quiet --bare "${test_dir}/origin.git"
git -C "${test_dir}/origin.git" symbolic-ref HEAD refs/heads/master
git init --quiet "${test_dir}/seed"
git -C "${test_dir}/seed" symbolic-ref HEAD refs/heads/master
mkdir -p "${test_dir}/seed/manifests/nodes"
: > "${test_dir}/seed/manifests/nodes/.keep"
printf 'original\n' > "${test_dir}/seed/version"
git -C "${test_dir}/seed" add .
git -C "${test_dir}/seed" -c user.name=Test -c user.email=test@example.invalid commit --quiet -m original
for branch in canary/recovery retired preserved; do
    git -C "${test_dir}/seed" branch "$branch"
done
git -C "${test_dir}/seed" remote add origin "${test_dir}/origin.git"
git -C "${test_dir}/seed" push --quiet --all origin

new_case() {
    WORKING_DIR="${test_dir}/$1"
    events="${test_dir}/$1.events"
    : > "$events"
    git clone --quiet --no-hardlinks "${test_dir}/origin.git" "$WORKING_DIR"
    PUPPET_REPO='https://github.com/mozilla-platform-ops/ronin_puppet.git'
    PUPPET_REPOSITORY_SLUG=mozilla-platform-ops/ronin_puppet
    PUPPET_BRANCH=canary/recovery
    RUN_PUPPET_GIT_AUTH_MODE=auto
    GIT_AUTH_MODE_SELECTED=deploy-key
    FQDN=test.example.invalid
    ROLE=gecko_t_linux_talos
    _GREEN='' _YELLOW='' _CYAN='' _DIM='' _RESET=''
}

# Reproduce both live and deleted empty refs, including an empty loose ref
# shadowing a packed value. The real update must fetch and select the canary.
new_case recovered_update
original=$(git -C "$WORKING_DIR" rev-parse HEAD)
git -C "$WORKING_DIR" tag keep
git -C "$WORKING_DIR" pack-refs --all
git -C "${test_dir}/seed" push --quiet origin :retired
printf 'updated\n' > "${test_dir}/seed/version"
git -C "${test_dir}/seed" -c user.name=Test -c user.email=test@example.invalid commit --quiet -am updated
git -C "${test_dir}/seed" push --quiet origin master master:canary/recovery
expected=$(git -C "${test_dir}/seed" rev-parse HEAD)
mkdir -p "$WORKING_DIR/.git/refs/remotes/origin/canary"
for ref in master retired canary/recovery; do
    : > "$WORKING_DIR/.git/refs/remotes/origin/$ref"
done
if git -C "$WORKING_DIR" fetch --prune origin > "${test_dir}/broken-fetch.log" 2>&1; then
    echo 'Fixture did not reproduce a failing fetch' >&2
    exit 1
fi
if ! (cd "$WORKING_DIR"; update_puppet) > "${test_dir}/recovered-update.log" 2>&1; then
    cat "${test_dir}/recovered-update.log" >&2
    exit 1
fi
[[ $(git -C "$WORKING_DIR" rev-parse HEAD) == "$expected" ]]
[[ $(git -C "$WORKING_DIR" rev-parse refs/remotes/origin/canary/recovery) == "$expected" ]]
[[ $(git -C "$WORKING_DIR" rev-parse refs/heads/master) == "$original" ]]
[[ $(git -C "$WORKING_DIR" rev-parse refs/tags/keep) == "$original" ]]
[[ $(git -C "$WORKING_DIR" rev-parse refs/remotes/origin/preserved) == "$original" ]]
if git -C "$WORKING_DIR" show-ref --verify --quiet refs/remotes/origin/retired; then exit 1; fi
backup=$(find "$WORKING_DIR/.git" -maxdepth 1 -type d -name 'ronin-empty-refs.*' -print)
[[ -n "$backup" ]]
for ref in master retired canary/recovery; do
    [[ -f "$backup/refs/remotes/origin/$ref" && ! -s "$backup/refs/remotes/origin/$ref" ]]
    [[ ! -e "$WORKING_DIR/.git/refs/remotes/origin/${ref}.lock" ]]
done
[[ $(cat "$events") == fetch ]]
printf 'PASS: damaged live/deleted/packed refs recover through fetch and branch selection\n'

new_case protected_refs
mkdir -p "$WORKING_DIR/.git/refs/tags"
: > "$WORKING_DIR/.git/refs/heads/empty-local"
: > "$WORKING_DIR/.git/refs/tags/empty-tag"
: > "$WORKING_DIR/.git/refs/remotes/origin/in-progress.lock"
printf 'nonempty invalid ref\n' > "$WORKING_DIR/.git/refs/remotes/origin/nonempty-invalid"
: > "${test_dir}/symlink-target"
ln -s "${test_dir}/symlink-target" "$WORKING_DIR/.git/refs/remotes/origin/symlink"
mkdir "${test_dir}/symlink-directory"
: > "${test_dir}/symlink-directory/untouched"
ln -s "${test_dir}/symlink-directory" "$WORKING_DIR/.git/refs/remotes/origin/directory-link"
(cd "$WORKING_DIR"; recover_empty_remote_refs)
[[ -f "$WORKING_DIR/.git/refs/heads/empty-local" ]]
[[ -f "$WORKING_DIR/.git/refs/tags/empty-tag" ]]
[[ -f "$WORKING_DIR/.git/refs/remotes/origin/in-progress.lock" ]]
[[ $(cat "$WORKING_DIR/.git/refs/remotes/origin/nonempty-invalid") == 'nonempty invalid ref' ]]
[[ -L "$WORKING_DIR/.git/refs/remotes/origin/symlink" && -f "${test_dir}/symlink-target" ]]
[[ -L "$WORKING_DIR/.git/refs/remotes/origin/directory-link" && -f "${test_dir}/symlink-directory/untouched" ]]
[[ -z $(find "$WORKING_DIR/.git" -maxdepth 1 -name 'ronin-empty-refs.*' -print) ]]
printf 'PASS: local refs, nonempty refs, lock files and symlinks are untouched\n'

new_case locked_ref
: > "$WORKING_DIR/.git/refs/remotes/origin/empty"
: > "$WORKING_DIR/.git/refs/remotes/origin/empty.lock"
if (cd "$WORKING_DIR"; update_puppet) > "${test_dir}/locked.log" 2>&1; then exit 1; fi
[[ -f "$WORKING_DIR/.git/refs/remotes/origin/empty" && ! -s "$events" ]]
grep -q 'Refusing to recover locked Git ref' "${test_dir}/locked.log"
printf 'PASS: a locked ref stops the update before fetch\n'

new_case move_failure
: > "$WORKING_DIR/.git/refs/remotes/origin/empty"
if (
    cd "$WORKING_DIR"
    # Called by the extracted recovery function.
    # shellcheck disable=SC2329
    mv() { return 1; }
    update_puppet
) > "${test_dir}/move-failure.log" 2>&1; then exit 1; fi
[[ -f "$WORKING_DIR/.git/refs/remotes/origin/empty" && ! -s "$events" ]]
[[ ! -e "$WORKING_DIR/.git/refs/remotes/origin/empty.lock" ]]
printf 'PASS: quarantine failure stops the update before fetch\n'

new_case repeated_recovery
for attempt in 1 2; do
    : > "$WORKING_DIR/.git/refs/remotes/origin/empty"
    (cd "$WORKING_DIR"; recover_empty_remote_refs)
done
[[ $(find "$WORKING_DIR/.git" -type f -path '*/ronin-empty-refs.*/refs/remotes/origin/empty' | wc -l | tr -d ' ') == 2 ]]
printf 'PASS: repeated recovery retains distinct backups\n'

new_case healthy_update
(cd "$WORKING_DIR"; update_puppet) > "${test_dir}/healthy.log" 2>&1
[[ -z $(find "$WORKING_DIR/.git" -maxdepth 1 -name 'ronin-empty-refs.*' -print) ]]
[[ $(git -C "$WORKING_DIR" rev-parse HEAD) == "$expected" ]]
printf 'PASS: healthy updates need no quarantine\n'

new_case stale_gc_log
printf 'fatal: bad object refs/remotes/origin/repaired\n' > "$WORKING_DIR/.git/gc.log"
(cd "$WORKING_DIR"; update_puppet) > "${test_dir}/stale-gc.log" 2>&1
[[ ! -e "$WORKING_DIR/.git/gc.log" && ! -e "$WORKING_DIR/.git/gc.log.lock" ]]
backup=$(find "$WORKING_DIR/.git" -maxdepth 1 -type d -name 'ronin-gc-log.*' -print)
[[ $(cat "$backup/gc.log") == 'fatal: bad object refs/remotes/origin/repaired' ]]
printf 'PASS: successful update archives the old gc log after connectivity validation\n'

new_case unresolved_corruption
printf 'original gc failure\n' > "$WORKING_DIR/.git/gc.log"
printf 'not-a-commit\n' > "$WORKING_DIR/.git/refs/remotes/origin/invalid"
(cd "$WORKING_DIR"; archive_git_gc_log) > "${test_dir}/unresolved.log" 2>&1
[[ $(cat "$WORKING_DIR/.git/gc.log") == 'original gc failure' ]]
[[ ! -e "$WORKING_DIR/.git/gc.log.lock" ]]
grep -q 'connectivity check failed' "${test_dir}/unresolved.log"
printf 'PASS: unresolved connectivity keeps the gc log and reports the problem\n'

new_case active_gc
printf 'original gc failure\n' > "$WORKING_DIR/.git/gc.log"
: > "$WORKING_DIR/.git/gc.log.lock"
(cd "$WORKING_DIR"; archive_git_gc_log) > "${test_dir}/locked-gc.log" 2>&1
[[ -f "$WORKING_DIR/.git/gc.log" && -f "$WORKING_DIR/.git/gc.log.lock" ]]
grep -q 'Leaving locked Git gc.log' "${test_dir}/locked-gc.log"
rm -- "$WORKING_DIR/.git/gc.log.lock"
printf '12345 host\n' > "$WORKING_DIR/.git/gc.pid"
(cd "$WORKING_DIR"; archive_git_gc_log) > "${test_dir}/active-gc.log" 2>&1
[[ -f "$WORKING_DIR/.git/gc.log" && ! -e "$WORKING_DIR/.git/gc.log.lock" ]]
grep -q 'while gc.pid exists' "${test_dir}/active-gc.log"
printf 'PASS: maintenance locks and pid files prevent gc log archival\n'

new_case unsafe_gc_log
printf 'external diagnostic\n' > "${test_dir}/external-gc.log"
ln -s "${test_dir}/external-gc.log" "$WORKING_DIR/.git/gc.log"
(cd "$WORKING_DIR"; archive_git_gc_log) > "${test_dir}/unsafe-gc.log" 2>&1
[[ -L "$WORKING_DIR/.git/gc.log" ]]
[[ $(cat "${test_dir}/external-gc.log") == 'external diagnostic' ]]
grep -q 'Leaving unsafe Git gc.log' "${test_dir}/unsafe-gc.log"
printf 'PASS: a symlinked gc log is never followed or moved\n'

new_case gc_archive_failure
printf 'original gc failure\n' > "$WORKING_DIR/.git/gc.log"
(
    cd "$WORKING_DIR"
    # Called by the extracted archive function.
    # shellcheck disable=SC2329
    mv() { return 1; }
    archive_git_gc_log
) > "${test_dir}/archive-failure.log" 2>&1
[[ -f "$WORKING_DIR/.git/gc.log" && ! -e "$WORKING_DIR/.git/gc.log.lock" ]]
grep -q 'Unable to archive Git gc.log' "${test_dir}/archive-failure.log"
printf 'PASS: failed archival preserves the log without blocking Puppet\n'

new_case retry_after_fetch_failure
printf 'original gc failure\n' > "$WORKING_DIR/.git/gc.log"
: > "$WORKING_DIR/.git/refs/remotes/origin/empty"
git -C "$WORKING_DIR" remote set-url origin "${test_dir}/missing.git"
if (cd "$WORKING_DIR"; update_puppet) > "${test_dir}/failed-fetch.log" 2>&1; then exit 1; fi
[[ -f "$WORKING_DIR/.git/gc.log" ]]
git -C "$WORKING_DIR" remote set-url origin "${test_dir}/origin.git"
(cd "$WORKING_DIR"; update_puppet) > "${test_dir}/retried-fetch.log" 2>&1
[[ ! -e "$WORKING_DIR/.git/gc.log" ]]
printf 'PASS: a later successful update archives the log after an earlier fetch failure\n'

bash "${repo_root}/test/test_run_puppet_git_auth.sh"
