#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Pick a working python3 and generate the SBOM.
#
# Not every macOS role installs packages::python3 (build and signing hosts
# don't), so fall back to the command line tools interpreter. Each candidate
# is probed before use: /usr/bin/python3 on a host without the CLT is a stub
# that fails rather than a usable interpreter.
#
# Always exits 0. An SBOM is never worth failing a Puppet run over.

set -u

SBOM_SCRIPT="/usr/local/bin/generate_sbom.py"

if [[ ! -f "${SBOM_SCRIPT}" ]]; then
    echo "generate_sbom: ${SBOM_SCRIPT} is missing" >&2
    exit 0
fi

for candidate in /usr/local/bin/python3 /usr/bin/python3; do
    if [[ -x "${candidate}" ]] && "${candidate}" -c 'import plistlib' >/dev/null 2>&1; then
        "${candidate}" "${SBOM_SCRIPT}" "$@" || \
            echo "generate_sbom: ${candidate} exited non-zero" >&2
        exit 0
    fi
done

echo "generate_sbom: no working python3 found, skipping SBOM" >&2
exit 0
