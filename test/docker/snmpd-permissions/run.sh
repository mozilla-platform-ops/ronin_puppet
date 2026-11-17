#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "$0")/../../.." && pwd -P)
image=ronin-test-snmpd-permissions
# Send only fixtures to Docker, excluding unrelated local files and credentials.
tar -C "$repo_root" -cf - \
    test/docker/snmpd-permissions/Dockerfile \
    test/docker/snmpd-permissions/test.sh \
    modules/linux_snmpd/templates/snmpd.conf.erb \
    | docker build --file test/docker/snmpd-permissions/Dockerfile --tag "$image" -
docker run --rm "$image"
