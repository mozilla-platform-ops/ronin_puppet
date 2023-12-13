#!/usr/bin/env bash

set -e
# set -x

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root!"
  exit 1
fi

# how to identify what to add
# - run `sqlite3 DB_PATH .dump` for system and user TCC DB and store output
#   - system: "/Library/Application Support/com.apple.TCC/TCC.db"
#   - user: "/Users/USER/Library/Application Support/com.apple.TCC/TCC.db"
# - run commands and approve the GUI permissions requests
# - run `sqlite3 DB_PATH .dump` for system and user TCC DB and compare to before dump output

# kTCCServiceAccessibility, in system TCC DB
query="REPLACE INTO access VALUES('kTCCServiceAccessibility','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'UNUSED',NULL,0,1702497218);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query"

# kTCCServiceAppleEvents, in user TCC DB
query1="REPLACE INTO access VALUES('kTCCServiceUbiquity','com.apple.Safari',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1702497181);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query1"


query2="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.passd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1702497185);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query2"

query3="REPLACE INTO access VALUES('kTCCServiceAppleEvents','/usr/libexec/sshd-keygen-wrapper',1,2,3,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'com.apple.systemevents',X'fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003',NULL,1702497200);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query3"