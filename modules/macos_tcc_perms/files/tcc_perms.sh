#!/usr/bin/env bash

set -e

# Run as root
# Running repeatedly will not create duplicate entries

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root!"
  exit 1
fi

# Function to execute the sqlite3 queries
execute_query() {
    local db_path=$1
    local query=$2
    sudo sqlite3 "$db_path" "$query"
}

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

queries_14_user=(
        "REPLACE INTO access VALUES('kTCCServiceAppleEvents','/usr/libexec/sshd-keygen-wrapper',1,2,3,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'com.apple.systemevents',X'fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003',NULL,1724935189,NULL,NULL,'UNUSED',1724935189);"
        "REPLACE INTO access VALUES('kTCCServiceMicrophone','/usr/local/bin/start-worker',1,2,2,1,X'fade0c00000000280000000100000008000000147f41aa3c67a93ccd54d2e21d25ba664a2db38497',NULL,NULL,'UNUSED',NULL,0,1733939621,NULL,NULL,'UNUSED',0);"
    )

queries_14_system=(
    "REPLACE INTO access VALUES('kTCCServiceScreenCapture','/bin/bash',1,2,4,1,X'fade0c000000002c0000000100000006000000020000000e636f6d2e6170706c652e62617368000000000003',NULL,0,'UNUSED',NULL,0,1712861877,NULL,NULL,'UNUSED',0);"
    "REPLACE INTO access VALUES('kTCCServiceScreenCapture','com.apple.Terminal',0,2,4,1,X'fade0c000000003000000001000000060000000200000012636f6d2e6170706c652e5465726d696e616c000000000003',NULL,0,'UNUSED',NULL,0,1712861890,NULL,NULL,'UNUSED',0);"
    "REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'UNUSED',NULL,0,1710355061,NULL,NULL,'UNUSED',1710355061);"
    "REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/sbin/sshd',1,2,4,1,X'fade0c000000002c0000000100000006000000020000000e636f6d2e6170706c652e73736864000000000003',NULL,0,'UNUSED',NULL,0,1712862105,NULL,NULL,'UNUSED',0);"
    "REPLACE INTO access VALUES('kTCCServiceScreenCapture','/usr/local/bin/start-worker',1,2,4,1,X'fade0c00000000280000000100000008000000147f41aa3c67a93ccd54d2e21d25ba664a2db38497',NULL,0,'UNUSED',NULL,0,1733939636,NULL,NULL,'UNUSED',0);"
)

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
    for query in "${queries_14_system[@]}"; do
        execute_query "/Library/Application Support/com.apple.TCC/TCC.db" "$query"
    done
    for query in "${queries_14_user[@]}"; do
        execute_query "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query"
    done
else
    echo "Unsupported macOS version: $macos_version"
    exit 1
fi

echo "Permissions updated successfully."
