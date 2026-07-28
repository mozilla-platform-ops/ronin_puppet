#!/usr/bin/env bash

set -e

# Run as root
# Running repeatedly will not create duplicate entries

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root!"
  exit 1
fi

# Function to execute the sqlite3 queries.
#
# A 5s busy timeout makes sqlite wait out a transiently-locked TCC.db instead
# of failing immediately with "database is locked (5)". This happens when
# puppet runs at boot while cltbld's autologin session is still initializing
# and the system briefly holds a write lock on the user TCC.db — without the
# timeout that race fails the whole puppet apply (and fires a failure email),
# even though a retry 60s later succeeds. The timeout is a cap, not a fixed
# delay: sqlite returns the instant the lock frees, so the normal unlocked path
# is not slowed. 5s comfortably covers the brief session-startup lock while
# keeping the worst-case wait bounded on these CI hosts; a genuinely stuck lock
# still fails (after 5s) so real problems are surfaced.
execute_query() {
    local db_path=$1
    local query=$2
    sudo sqlite3 -cmd ".timeout 5000" "$db_path" "$query"
}

# Build a TCC csreq blob (cdhash-anchored code requirement) for a given binary.
# The csreq format is:
#   FADE0C00 00000028 00000001 00000008 00000014 <20-byte cdhash>
# Echoes the SQL X'...' literal, or empty string if cdhash cannot be read.
#
# We capture cdhashes at runtime because ad-hoc-signed binaries
# (start-worker, generic-worker-multiuser) have cdhashes that change with
# every binary version bump. Hardcoding produced stale csreq blobs that
# TCC silently rejected — the grant row was stored but ignored at policy
# evaluation, manifesting as `NotAllowedError` in mediacapture-streams
# tests despite the user-DB entry appearing to exist.
csreq_for_binary() {
    local bin_path=$1
    local cdhash
    cdhash=$(codesign -dvvv "$bin_path" 2>&1 | awk -F= '/^CDHash=/{print $2; exit}')
    if [ -z "$cdhash" ]; then
        echo "WARNING: could not read cdhash for ${bin_path}; skipping its TCC entries" >&2
        return 0
    fi
    printf "X'fade0c0000000028000000010000000800000014%s'" "$cdhash"
}

# Detect SIP state. On SIP-off hosts (existing pre-PR prod m4 fleet) we still
# need to write the system TCC DB directly via sqlite3 — preserves the
# behavior these workers have always had. On SIP-on hosts (the new
# SIP-compatible fleet) those writes silently fail; the equivalent
# system-level grants come from the org.mozilla.ci-tcc-pppc MDM profile
# deployed via SimpleMDM instead.
#
# Default to SIP-off (legacy behavior). Only treat the host as SIP-on when
# csrutil status clearly says "enabled". Some hosts return output like
# "unknown (Custom Configuration)" when SIP is in a partial/custom state;
# a naive `grep "disabled"` misses those and silently skips the system-DB
# writes that the legacy fleet relies on. Fail-safe to preserving legacy
# behavior for anything ambiguous.
SIP_DISABLED=true
if csrutil status 2>/dev/null | grep -qiE "status:[[:space:]]*enabled\.?$"; then
    SIP_DISABLED=false
fi

# Get the macOS version
macos_version=$(sw_vers -productVersion)
macos_major_version=$(echo "$macos_version" | cut -d'.' -f1)
macos_minor_version=$(echo "$macos_version" | cut -d'.' -f2)

# Define the queries for different macOS versions
queries_10_15_user=(
    "REPLACE INTO access VALUES('kTCCServiceAppleEvents','/usr/libexec/sshd-keygen-wrapper',1,1,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'com.apple.systemevents',X'fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003',NULL,1666043382);"
)

queries_10_15_system=(
    "REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/sbin/sshd',1,1,1,NULL,NULL,NULL,'UNUSED',NULL,0,1612998569);"
    "REPLACE INTO access VALUES('kTCCServicePostEvent','com.apple.screensharing.agent',0,1,1,NULL,NULL,NULL,'UNUSED',NULL,0,1613096512);"
    "REPLACE INTO access VALUES('kTCCServiceScreenCapture','com.apple.screensharing.agent',0,1,1,NULL,NULL,NULL,'UNUSED',NULL,0,1613096512);"
    "REPLACE INTO access VALUES('kTCCServiceAccessibility','/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/AE.framework/Versions/A/Support/AEServer',1,0,1,NULL,NULL,NULL,'UNUSED',NULL,0,1613096512);"
    "REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/libexec/sshd-keygen-wrapper',1,1,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,NULL,'UNUSED',NULL,0,1613151623);"
    "REPLACE INTO access VALUES('kTCCServiceDeveloperTool','com.apple.Terminal',0,0,1,NULL,NULL,NULL,'UNUSED',NULL,0,1613151749);"
    "REPLACE INTO access VALUES('kTCCServiceScreenCapture','/bin/bash',1,1,1,X'fade0c000000002c0000000100000006000000020000000e636f6d2e6170706c652e62617368000000000003',NULL,NULL,'UNUSED',NULL,0,1630007351);"
    "REPLACE INTO access VALUES('kTCCServiceScreenCapture','com.apple.Terminal',0,1,1,X'fade0c000000003000000001000000060000000200000012636f6d2e6170706c652e5465726d696e616c000000000003',NULL,NULL,'UNUSED',NULL,0,1695227249);"
)

queries_11_12_13=(
    "REPLACE INTO access VALUES('kTCCServiceScreenCapture','/bin/bash',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002326);"
    "REPLACE INTO access VALUES('kTCCServiceScreenCapture','com.apple.Terminal',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002339);"
    "REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002842);"
    "REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/sbin/sshd',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002869);"
)

# macOS 14/15 user-DB entries — written on every host. Root can always
# write user TCC DBs in cltbld's home regardless of SIP state.
queries_14_user=(
    "REPLACE INTO access VALUES('kTCCServiceAppleEvents','/usr/libexec/sshd-keygen-wrapper',1,2,3,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'com.apple.systemevents',X'fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003',NULL,1724935189,NULL,NULL,'UNUSED',1724935189);"
)

# macOS 14/15 system-DB entries — written ONLY when SIP is disabled.
# On SIP-on hosts the equivalent grants are supplied by the
# org.mozilla.ci-tcc-pppc MDM profile (SystemPolicyAllFiles for sshd /
# sshd-keygen-wrapper). ScreenCapture cannot be expressed in PPPC on
# macOS 15 (ErrorCode 22), so it stays SIP-off-only here.
queries_14_system=(
    "REPLACE INTO access VALUES('kTCCServiceScreenCapture','/bin/bash',1,2,4,1,X'fade0c000000002c0000000100000006000000020000000e636f6d2e6170706c652e62617368000000000003',NULL,0,'UNUSED',NULL,0,1712861877,NULL,NULL,'UNUSED',0);"
    "REPLACE INTO access VALUES('kTCCServiceScreenCapture','com.apple.Terminal',0,2,4,1,X'fade0c000000003000000001000000060000000200000012636f6d2e6170706c652e5465726d696e616c000000000003',NULL,0,'UNUSED',NULL,0,1712861890,NULL,NULL,'UNUSED',0);"
    "REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'UNUSED',NULL,0,1710355061,NULL,NULL,'UNUSED',1710355061);"
    "REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/sbin/sshd',1,2,4,1,X'fade0c000000002c0000000100000006000000020000000e636f6d2e6170706c652e73736864000000000003',NULL,0,'UNUSED',NULL,0,1712862105,NULL,NULL,'UNUSED',0);"
)

# Dynamically-csreq'd entries for ad-hoc-signed worker binaries. Microphone
# always goes to user DB (no SIP impact). ScreenCapture goes to system DB on
# SIP-off (matches the legacy fleet's prior behavior so existing prod m4
# workers don't regress) and to user DB on SIP-on as a best-effort fallback
# while we wait on Developer ID signing
# (https://github.com/taskcluster/taskcluster/issues/7413).
start_worker_csreq=$(csreq_for_binary /usr/local/bin/start-worker)
gw_multiuser_csreq=$(csreq_for_binary /usr/local/bin/generic-worker-multiuser)

if [ -n "$start_worker_csreq" ]; then
    queries_14_user+=("REPLACE INTO access VALUES('kTCCServiceMicrophone','/usr/local/bin/start-worker',1,2,2,1,${start_worker_csreq},NULL,NULL,'UNUSED',NULL,0,1733939621,NULL,NULL,'UNUSED',0);")
    if [ "$SIP_DISABLED" = "true" ]; then
        queries_14_system+=("REPLACE INTO access VALUES('kTCCServiceScreenCapture','/usr/local/bin/start-worker',1,2,4,1,${start_worker_csreq},NULL,0,'UNUSED',NULL,0,1733939636,NULL,NULL,'UNUSED',0);")
    else
        queries_14_user+=("REPLACE INTO access VALUES('kTCCServiceScreenCapture','/usr/local/bin/start-worker',1,2,4,1,${start_worker_csreq},NULL,0,'UNUSED',NULL,0,1733939636,NULL,NULL,'UNUSED',0);")
    fi
fi

if [ -n "$gw_multiuser_csreq" ]; then
    queries_14_user+=("REPLACE INTO access VALUES('kTCCServiceMicrophone','/usr/local/bin/generic-worker-multiuser',1,2,2,1,${gw_multiuser_csreq},NULL,NULL,'UNUSED',NULL,0,1776863417,NULL,NULL,'UNUSED',0);")
    if [ "$SIP_DISABLED" = "true" ]; then
        queries_14_system+=("REPLACE INTO access VALUES('kTCCServiceScreenCapture','/usr/local/bin/generic-worker-multiuser',1,2,4,1,${gw_multiuser_csreq},NULL,0,'UNUSED',NULL,0,1776863417,NULL,NULL,'UNUSED',0);")
    else
        queries_14_user+=("REPLACE INTO access VALUES('kTCCServiceScreenCapture','/usr/local/bin/generic-worker-multiuser',1,2,4,1,${gw_multiuser_csreq},NULL,0,'UNUSED',NULL,0,1776863417,NULL,NULL,'UNUSED',0);")
    fi
fi

# Execute the appropriate queries based on the macOS version
if [[ "$macos_major_version" -eq 10 && "$macos_minor_version" -eq 15 ]]; then
    for query in "${queries_10_15_user[@]}"; do
        execute_query "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query"
    done
    for query in "${queries_10_15_system[@]}"; do
        execute_query "/Library/Application Support/com.apple.TCC/TCC.db" "$query"
    done
elif [[ "$macos_major_version" -eq 11 || "$macos_major_version" -eq 12 || "$macos_major_version" -eq 13 ]]; then
    for query in "${queries_11_12_13[@]}"; do
        execute_query "/Library/Application Support/com.apple.TCC/TCC.db" "$query"
    done
elif [[ "$macos_major_version" -eq 14 || "$macos_major_version" -eq 15 ]]; then
    for query in "${queries_14_user[@]}"; do
        execute_query "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query"
    done
    # System-DB writes only on SIP-off hosts. On SIP-on hosts the equivalent
    # grants come from the org.mozilla.ci-tcc-pppc MDM profile.
    if [ "$SIP_DISABLED" = "true" ]; then
        for query in "${queries_14_system[@]}"; do
            execute_query "/Library/Application Support/com.apple.TCC/TCC.db" "$query"
        done
    fi
else
    echo "Unsupported macOS version: $macos_version"
    exit 1
fi

echo "Permissions updated successfully."
mkdir -p /var/tmp/semaphore
touch /var/tmp/semaphore/tcc-perms-applied
