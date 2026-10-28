#!/usr/bin/env bash
# Exercise the Linux wrapper's public-only fetch fallback without network access.
# ShellCheck cannot follow the functions extracted from the ERB template.
# shellcheck disable=SC1090,SC2034
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
template="${repo_root}/modules/puppet/templates/puppet-ubuntu-run-puppet.sh.erb"
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/run-puppet-auth-test.XXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT

for function_name in configure_git_remote configure_public_anonymous_auth fetch_puppet_remote; do
    source <(sed -n "/^function ${function_name} {/,/^}/p" "$template")
done
# update_puppet contains a heredoc whose node-closing brace is at column zero.
source <(sed -n '/^function update_puppet {/,/^function recover_interrupted_dpkg {/p' "$template" | sed '$d')

git() {
    case "$*" in
        *'fetch --all --prune' | *'fetch --prune origin')
            printf 'fetch:%s\n' "$GIT_AUTH_MODE_SELECTED" >> "$events"
            [ "$GIT_AUTH_MODE_SELECTED" = anonymous ] && [ "$anonymous_fetch_result" = success ]
            ;;
        'rev-parse --verify HEAD') printf 'abcdef0\n' ;;
        'rev-parse --git-dir') printf '.git\n' ;;
        'remote get-url origin') printf '%s\n' "$GIT_REMOTE_URL" ;;
        'remote set-url origin '* ) printf 'remote:%s\n' "$4" >> "$events" ;;
        'config --unset-all http.https://github.com/.extraHeader') return 5 ;;
        'checkout --quiet --force '* ) return 0 ;;
        'log -1 --oneline '* ) printf 'abcdef0 test revision\n' ;;
        *) printf 'Unexpected git invocation: %s\n' "$*" >&2; return 1 ;;
    esac
}

require_secure_working_dir() { :; }
clear_git_pat_auth() { GIT_PAT_HEADER=''; }
remove_staged_vault_secrets() { :; }
reinit_working_dir() {
    printf 'reinit\n' >> "$events"
    return 1
}

run_case() {
    local name=$1 repo=$2 requested_mode=$3 anonymous_result=$4 expected_result=$5
    WORKING_DIR="${test_dir}/${name}"
    events="${WORKING_DIR}/events"
    mkdir -p "$WORKING_DIR/.git/objects" "$WORKING_DIR/manifests/nodes"
    : > "$events"
    PUPPET_REPO=$repo
    PUPPET_BRANCH=master
    PUPPET_REPOSITORY_SLUG=${repo#https://github.com/}
    PUPPET_REPOSITORY_SLUG=${PUPPET_REPOSITORY_SLUG%.git}
    RUN_PUPPET_GIT_AUTH_MODE=$requested_mode
    GIT_AUTH_MODE_SELECTED=${6:-deploy-key}
    if [ "$GIT_AUTH_MODE_SELECTED" = pat ]; then
        GIT_REMOTE_URL=$PUPPET_REPO
    else
        GIT_REMOTE_URL="ssh://git@ssh.github.com:443/${PUPPET_REPOSITORY_SLUG}.git"
    fi
    FQDN=test.example.com
    ROLE=gecko_t_linux_talos
    anonymous_fetch_result=$anonymous_result
    _GREEN='' _YELLOW='' _CYAN='' _DIM='' _RESET=''

    cd "$WORKING_DIR"
    if update_puppet >/dev/null 2>&1; then
        [ "$expected_result" = success ] || { printf '%s unexpectedly succeeded\n' "$name" >&2; exit 1; }
    else
        [ "$expected_result" = failure ] || { printf '%s unexpectedly failed\n' "$name" >&2; exit 1; }
    fi
}

public_repo='https://github.com/mozilla-platform-ops/ronin_puppet.git'
private_repo='https://github.com/aerickson/ronin_puppet-private.git'

run_case public_fallback "$public_repo" auto success success
grep -q '^fetch:deploy-key$' "$events"
grep -q '^fetch:anonymous$' "$events"
grep -q "^remote:${public_repo}$" "$events"
if grep -q '^reinit$' "$events"; then exit 1; fi
[ "$GIT_AUTH_MODE_SELECTED" = anonymous ]

run_case public_both_fail "$public_repo" auto failure failure
grep -q '^fetch:anonymous$' "$events"
if grep -q '^reinit$' "$events"; then exit 1; fi

run_case public_pat_fallback "$public_repo" auto success success pat
grep -q '^fetch:pat$' "$events"
grep -q '^fetch:anonymous$' "$events"
if grep -q '^reinit$' "$events"; then exit 1; fi

run_case private_fail "$private_repo" auto success failure
if grep -q '^fetch:anonymous$' "$events"; then exit 1; fi
grep -q '^reinit$' "$events"

run_case forced_deploy_key "$public_repo" deploy-key success failure
if grep -q '^fetch:anonymous$' "$events"; then exit 1; fi
grep -q '^reinit$' "$events"

run_case forced_pat "$public_repo" pat success failure pat
if grep -q '^fetch:anonymous$' "$events"; then exit 1; fi
grep -q '^reinit$' "$events"

printf 'Linux run-puppet Git auth fallback tests passed.\n'
