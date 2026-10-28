#!/usr/bin/env bash
# Test release-package installation without root, network, or package changes.
# shellcheck disable=SC1090
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
script="${repo_root}/provisioners/linux/bootstrap_bitbar_devicepool.sh"
test_dir=$(command mktemp -d "${TMPDIR:-/tmp}/bitbar-release-test.XXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT
source <(sed -n '/^function install_puppet_release {/,/^}/p' "$script")

mktemp() {
    [ "$*" = '-d /root/puppet-release.XXXXXX' ] || return 1
    command mktemp -d "${test_dir}/puppet-release.XXXXXX"
}
lsb_release() { printf 'jammy\n'; }
wget() {
    [ "$#" -eq 4 ] && [ "$1" = --https-only ] && [ "$2" = -O ] || return 1
    [ "$4" = 'https://apt.puppetlabs.com/puppet7-release-jammy.deb' ] || return 1
    [ "$(dirname "$3")" != "$test_dir" ] || return 1
    printf '%s\n' "$3" >"${test_dir}/download-path"
    printf 'release package\n' >"$3"
    [ "$download_result" = success ]
}
dpkg() {
    [ "$#" -eq 2 ] && [ "$1" = -i ] || return 1
    [ "$2" = "$(cat "${test_dir}/download-path")" ] || return 1
    [ "$(cat "$2")" = 'release package' ] || return 1
    printf '%s\n' "$2" >"${test_dir}/install-path"
    [ "$install_result" = success ]
}

# An unrelated planted package must neither be installed nor deleted.
printf 'unrelated package\n' >"${test_dir}/unrelated.deb"
for scenario in success download_failure install_failure; do
    download_result=success
    install_result=success
    case "$scenario" in
        download_failure) download_result=failure ;;
        install_failure) install_result=failure ;;
    esac
    rm -f "${test_dir}/install-path"
    if install_puppet_release; then
        [ "$scenario" = success ] || exit 1
    else
        [ "$scenario" != success ] || exit 1
    fi
    package_path=$(cat "${test_dir}/download-path")
    [ ! -e "$(dirname "$package_path")" ] || exit 1
    if [ "$scenario" = download_failure ]; then
        [ ! -e "${test_dir}/install-path" ] || exit 1
    else
        [ -f "${test_dir}/install-path" ] || exit 1
    fi
    [ "$(cat "${test_dir}/unrelated.deb")" = 'unrelated package' ] || exit 1
    printf 'Passed: %s, exact package selection, and staging cleanup\n' "$scenario"
done
