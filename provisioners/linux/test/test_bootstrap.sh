#!/bin/bash
# Tests that bootstrap_linux.sh successfully installs openvox-agent on a given
# Ubuntu version. The script is expected to exit early at the NTP/systemd step
# since Docker containers don't have an init system — that's fine, openvox is
# installed before that point.
#
# Usage: ./test_bootstrap.sh <ubuntu-version>
#        ./test_bootstrap.sh 18.04
#        ./test_bootstrap.sh 24.04

set -e

UBUNTU_VERSION="${1:-}"

if [ -z "$UBUNTU_VERSION" ]; then
    echo "Usage: $0 <ubuntu-version>"
    echo "       $0 18.04"
    echo "       $0 24.04"
    exit 1
fi

case "$UBUNTU_VERSION" in
    18.04|24.04) ;;
    *)
        echo "Unsupported version: $UBUNTU_VERSION (supported: 18.04, 24.04)"
        exit 1
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_SCRIPT="${SCRIPT_DIR}/../bootstrap_linux.sh"

if [ ! -f "$BOOTSTRAP_SCRIPT" ]; then
    echo "Bootstrap script not found: $BOOTSTRAP_SCRIPT"
    exit 1
fi

CONTAINER_ID=""
cleanup() {
    if [ -n "$CONTAINER_ID" ]; then
        echo "==> Cleaning up container"
        docker rm -f "$CONTAINER_ID" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

echo "==> Starting ubuntu:${UBUNTU_VERSION} container"
CONTAINER_ID=$(docker run -d "ubuntu:${UBUNTU_VERSION}" sleep infinity)

echo "==> Installing prerequisite: wget"
docker exec "$CONTAINER_ID" bash -c "apt-get update -qq && apt-get install -y -qq wget"

echo "==> Copying bootstrap_linux.sh"
docker cp "$BOOTSTRAP_SCRIPT" "$CONTAINER_ID:/root/bootstrap_linux.sh"

echo "==> Creating stub /root/vault.yaml"
docker exec "$CONTAINER_ID" bash -c "echo '---' > /root/vault.yaml"

echo "==> Running bootstrap_linux.sh"
docker exec -e SKIP_NTP=true "$CONTAINER_ID" bash /root/bootstrap_linux.sh || true

echo "==> Checking openvox-agent installation"
if docker exec "$CONTAINER_ID" dpkg-query -W -f='${Status}' openvox-agent 2>/dev/null | grep -q "install ok installed"; then
    echo "PASS: openvox-agent is installed on Ubuntu ${UBUNTU_VERSION}"
else
    echo "FAIL: openvox-agent is not installed on Ubuntu ${UBUNTU_VERSION}"
    exit 1
fi
