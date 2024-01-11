#!/usr/bin/env bash

set -e

# Run as root
# For the r8s/macOS 10.15 only
# Running repeatedly will not create duplicate entries

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root!"
  exit 1
fi

# User values
query1="REPLACE INTO access VALUES('kTCCServiceAppleEvents','/usr/libexec/sshd-keygen-wrapper',1,1,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'com.apple.systemevents',X'fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003',NULL,1666043382);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query1"

# System values
query2="REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/sbin/sshd',1,1,1,NULL,NULL,NULL,'UNUSED',NULL,0,1612998569);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query2"

query3="REPLACE INTO access VALUES('kTCCServicePostEvent','com.apple.screensharing.agent',0,1,1,NULL,NULL,NULL,'UNUSED',NULL,0,1613096512);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query3"

query4="REPLACE INTO access VALUES('kTCCServiceScreenCapture','com.apple.screensharing.agent',0,1,1,NULL,NULL,NULL,'UNUSED',NULL,0,1613096512);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query4"

query5="REPLACE INTO access VALUES('kTCCServiceAccessibility','/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/AE.framework/Versions/A/Support/AEServer',1,0,1,NULL,NULL,NULL,'UNUSED',NULL,0,1613096512);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query5"

query6="REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/libexec/sshd-keygen-wrapper',1,1,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,NULL,'UNUSED',NULL,0,1613151623);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query6"

query7="REPLACE INTO access VALUES('kTCCServiceDeveloperTool','com.apple.Terminal',0,0,1,NULL,NULL,NULL,'UNUSED',NULL,0,1613151749);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query7"

query8="REPLACE INTO access VALUES('kTCCServiceScreenCapture','/bin/bash',1,1,1,X'fade0c000000002c0000000100000006000000020000000e636f6d2e6170706c652e62617368000000000003',NULL,NULL,'UNUSED',NULL,0,1630007351);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query8"

query9="REPLACE INTO access VALUES('kTCCServiceScreenCapture','com.apple.Terminal',0,1,1,X'fade0c000000003000000001000000060000000200000012636f6d2e6170706c652e5465726d696e616c000000000003',NULL,NULL,'UNUSED',NULL,0,1695227249);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query9"
