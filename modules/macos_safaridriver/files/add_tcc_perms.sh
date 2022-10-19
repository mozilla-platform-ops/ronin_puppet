#!/usr/bin/env bash

set -e
# set -x

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root!"
  exit 1
fi

# tool_path="/usr/local/bin"

# kTCCServiceAccessibility, in system TCC DB
# python ${tool_path}/tccutil.py -i /usr/libexec/sshd-keygen-wrapper
query="REPLACE INTO access VALUES('kTCCServiceAccessibility','/usr/libexec/sshd-keygen-wrapper',1,1,1,NULL,NULL,NULL,'UNUSED',NULL,0,0);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query"
# needed?
# query="REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/libexec/sshd-keygen-wrapper',1,1,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,NULL,'UNUSED',NULL,0,1618013664);"
# sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query"

# kTCCServiceAppleEvents, in user TCC DB
#   - not using tccutil due to funky binary data
query="REPLACE INTO access VALUES('kTCCServiceAppleEvents','/usr/libexec/sshd-keygen-wrapper',1,1,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'com.apple.systemevents',X'fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003',NULL,1666043382);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query"
