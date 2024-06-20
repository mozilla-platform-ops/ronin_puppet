#!/usr/bin/env bash

set -e

# Run as root
# For macOS14

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root!"
  exit 1
fi

# Gives Terminal and bash Screen Recording permissions

query1="REPLACE INTO access VALUES('kTCCServiceScreenCapture','/bin/bash',1,2,4,1,X'fade0c000000002c0000000100000006000000020000000e636f6d2e6170706c652e62617368000000000003',NULL,0,'UNUSED',NULL,0,1712861877,NULL,NULL,'UNUSED',0);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query1"

query2="REPLACE INTO access VALUES('kTCCServiceScreenCapture','com.apple.Terminal',0,2,4,1,X'fade0c000000003000000001000000060000000200000012636f6d2e6170706c652e5465726d696e616c000000000003',NULL,0,'UNUSED',NULL,0,1712861890,NULL,NULL,'UNUSED',0);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query2"

query3="REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'UNUSED',NULL,0,1710355061,NULL,NULL,'UNUSED',1710355061);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query3"

query4="REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/sbin/sshd',1,2,4,1,X'fade0c000000002c0000000100000006000000020000000e636f6d2e6170706c652e73736864000000000003',NULL,0,'UNUSED',NULL,0,1712862105,NULL,NULL,'UNUSED',0);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query4"
