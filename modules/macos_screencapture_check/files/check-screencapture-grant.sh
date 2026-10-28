#!/bin/bash
#
# Report whether the Taskcluster worker binaries and the failure-screenshot helper
# (/bin/bash) hold an effective Screen Recording (kTCCServiceScreenCapture) grant.
# Read-only: this never changes TCC state.
#
#   exit 0  every binary is granted
#   exit 1  at least one is not (or the state could not be read)
#
# Also writes a JSON status file for ingestion (telegraf / Hangar), because the
# point of this script is that a host WITHOUT the grant should be visible. When it
# is missing, the only symptom is getDisplayMedia() failing with
# SCStreamErrorUserDeclined (-3801), which surfaces as an intermittent orange on a
# random-looking subset of the pool -- bug 2073303 went 499 failures over 30 days
# before anyone traced it to the hosts rather than to Gecko.
#
# Reads the SYSTEM TCC database deliberately. kTCCServiceScreenCapture is a
# system-scoped service: a row in a user database is never consulted by TCC and
# must not be mistaken for a grant. macos_tcc_perms writes exactly such a row as a
# fallback on SIP-on hosts, where it is inert.
#
# auth_value 2 is granted. 0 is not, in either of its forms: auth_reason 4 is a
# system-set denial, auth_reason 6 is the policy-seeded "a standard user may grant
# this" placeholder that a ScreenCapture PPPC profile leaves behind.
#
# flags matters as much as auth_value. A grant approved while a ScreenCapture PPPC
# override was installed is recorded as MDM-managed (flags 12) and TCC then ignores
# it -- it looks correct in System Settings and in the access table, and does not
# work. Only flags 0 (user-approved) and 4 (written directly by sqlite3, the SIP-off
# path) are honoured. Checking auth_value alone would call a broken host healthy.
#
# sqlite3 can read this database because org.mozilla.ci-tcc-pppc grants it
# SystemPolicyAllFiles. Without that it exits non-zero and we report "unknown"
# rather than inventing a pass.

set -u

TCC_DB="/Library/Application Support/com.apple.TCC/TCC.db"
STATUS_FILE="${SCREENCAPTURE_STATUS_FILE:-/var/tmp/screencapture-grant-status.json}"

# /bin/bash is the failure-screenshot LaunchAgent (macos_screenshot_helper runs a
# bash script, so TCC attributes its captures to bash). Without its grant every
# failure screenshot is wallpaper-only, with no error anywhere (RELOPS-2454).
CLIENTS=(
    /usr/local/bin/generic-worker-multiuser
    /usr/local/bin/start-worker
    /bin/bash
)

sip="enabled"
if /usr/bin/csrutil status 2>/dev/null | grep -qi disabled; then
    sip="disabled"
fi

rc=0
entries=""
for client in "${CLIENTS[@]}"; do
    row=$(/usr/bin/sqlite3 -cmd ".timeout 5000" "$TCC_DB" \
        "SELECT auth_value || '/' || flags FROM access
          WHERE service = 'kTCCServiceScreenCapture'
            AND client  = '${client}';" 2>/dev/null)

    case "${row:-none}" in
        2/0|2/4) state="granted" ;;
        2/12)    state="ignored-mdm-managed" ; rc=1 ;;
        none)    state="absent"              ; rc=1 ;;
        *)       state="denied"              ; rc=1 ;;
    esac

    [ -n "$entries" ] && entries="${entries},"
    entries="${entries}{\"client\":\"${client}\",\"row\":\"${row:-none}\",\"state\":\"${state}\"}"
    [ "$state" = "granted" ] || echo "ScreenCapture ${state} for ${client} (auth_value/flags=${row:-none})" >&2
done

overall="granted"
[ "$rc" -eq 0 ] || overall="not-granted"

umask 022
cat > "${STATUS_FILE}.tmp" <<JSON
{"schema":1,"checked_at":"$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)","hostname":"$(/bin/hostname -s)","sip":"${sip}","status":"${overall}","clients":[${entries}]}
JSON
/bin/mv -f "${STATUS_FILE}.tmp" "${STATUS_FILE}"

exit "$rc"
