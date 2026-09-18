#!/bin/bash
#
# Exit 0 when every worker binary already holds an effective Screen Recording
# grant, non-zero otherwise. Used as the `unless` for the approval exec, so the
# real TCC state -- not a semaphore -- decides whether the GUI flow runs.
#
# Reads the SYSTEM TCC database on purpose. kTCCServiceScreenCapture is a
# system-scoped service: a row in a user database (which is what macos_tcc_perms
# falls back to writing on SIP-on hosts) is never consulted by TCC and must not
# be mistaken for a grant.
#
# auth_value 2 is allowed. 0 is not: on a SIP-on host without the ScreenCapture
# PPPC profile it is a system-set denial (auth_reason 4), and with the profile it
# is the policy-seeded "a standard user may grant this" placeholder
# (auth_reason 6). Neither permits capture, so both must re-run the approval.
#
# sqlite3 can read this database because the org.mozilla.ci-tcc-pppc profile
# grants SystemPolicyAllFiles to /usr/bin/sqlite3. Without that, sqlite3 exits
# non-zero with "authorization denied" and we correctly report "not granted"
# rather than assuming success.

set -u

TCC_DB="/Library/Application Support/com.apple.TCC/TCC.db"

CLIENTS=(
    /usr/local/bin/generic-worker-multiuser
    /usr/local/bin/start-worker
)

for client in "${CLIENTS[@]}"; do
    auth=$(/usr/bin/sqlite3 -cmd ".timeout 5000" "$TCC_DB" \
        "SELECT auth_value FROM access
          WHERE service = 'kTCCServiceScreenCapture'
            AND client = '${client}';" 2>/dev/null)
    if [ "$auth" != "2" ]; then
        echo "ScreenCapture not granted for ${client} (auth_value=${auth:-none})" >&2
        exit 1
    fi
done

exit 0
