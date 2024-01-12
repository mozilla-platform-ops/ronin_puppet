#!/usr/bin/env bash

set -e

# Run as root
# For macOS11/m1 pool

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root!"
  exit 1
fi

# Gives Terminal and bash Screen Recording permissions
query1="REPLACE INTO access VALUES('kTCCServiceScreenCapture','/bin/bash',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002326);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query1"

query2="REPLACE INTO access VALUES('kTCCServiceScreenCapture','com.apple.Terminal',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002339);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query2"

query3="REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002842);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query3"

query4="REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/sbin/sshd',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002869);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query4"
