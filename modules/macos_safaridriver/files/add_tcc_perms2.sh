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
query="REPLACE INTO access VALUES('kTCCServiceAccessibility','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002842);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query"

query2="REPLACE INTO access VALUES('kTCCServiceDeveloperTool','com.apple.Terminal',0,0,4,1,NULL,NULL,0,'UNUSED',NULL,0,1630422453);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query2"

query3="REPLACE INTO access VALUES('kTCCServiceScreenCapture','com.apple.bash',0,0,6,2,X'fade0c000000002c0000000100000006000000020000000e636f6d2e6170706c652e62617368000000000003',NULL,NULL,'UNUSED',NULL,12,1630430315);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query3"

query4="REPLACE INTO access VALUES('kTCCServiceScreenCapture','/opt/homebrew/Cellar/python@3.9/3.9.5/Frameworks/Python.framework/Versions/3.9/bin/python3.9',1,0,6,2,X'fade0c00000000280000000100000008000000144ac5131b3ef95d76e8bd44eef81ba8debe1d0744',NULL,NULL,'UNUSED',NULL,12,1630430315);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query4"

query5="REPLACE INTO access VALUES('kTCCServiceScreenCapture','/opt/homebrew/Frameworks/Python.framework/Versions/3.9/bin/python3.9',1,0,6,2,X'fade0c00000000280000000100000008000000144ac5131b3ef95d76e8bd44eef81ba8debe1d0744',NULL,NULL,'UNUSED',NULL,12,1630430315);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query5"

query6="REPLACE INTO access VALUES('kTCCServiceScreenCapture','/usr/local/bin/python3',1,0,6,2,X'fade0c00000000280000000100000008000000144ac5131b3ef95d76e8bd44eef81ba8debe1d0744',NULL,NULL,'UNUSED',NULL,12,1630430315);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query6"

query7="REPLACE INTO access VALUES('kTCCServiceScreenCapture','/usr/local/bin/start-worker',1,0,6,2,X'fade0c0000000028000000010000000800000014f9da98e56dfa9c01419369e4dd43cd9d29a6f2e1',NULL,NULL,'UNUSED',NULL,12,1630430315);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query7"

query8="REPLACE INTO access VALUES('kTCCServiceScreenCapture','/usr/local/bin/generic-worker-simple',1,0,6,2,X'fade0c0000000028000000010000000800000014454b43afc7c449e66bb0014ee5329324c0c4ad3c',NULL,NULL,'UNUSED',NULL,12,1630430315);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query8"

query9="REPLACE INTO access VALUES('kTCCServicePostEvent','com.apple.screensharing.agent',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1631200687);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query9"

query10="REPLACE INTO access VALUES('kTCCServiceScreenCapture','com.apple.screensharing.agent',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1631200687);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query10"

query11="REPLACE INTO access VALUES('kTCCServiceScreenCapture','/bin/bash',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002326);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query11"

query12="REPLACE INTO access VALUES('kTCCServiceScreenCapture','com.apple.Terminal',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002339);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query12"

query13="REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002842);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query13"

query14="REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/sbin/sshd',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002869);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query14"

query15="REPLACE INTO access VALUES('kTCCServiceAccessibility','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002842);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query15"

query16="REPLACE INTO access VALUES('kTCCServiceAccessibility','/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/AE.framework/Versions/A/Support/AEServer',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705601932);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query16"

query17="REPLACE INTO access VALUES('kTCCServiceAccessibility','com.apple.Terminal',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705601934);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query17"


# kTCCServiceAppleEvents, in user TCC DB
query18="REPLACE INTO access VALUES('kTCCServiceAppleEvents','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002842);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query18"

query19="REPLACE INTO access VALUES('kTCCServiceUbiquity','/System/Library/PrivateFrameworks/ContactsDonation.framework/Versions/A/Support/contactsdonationagent',1,2,5,1,NULL,NULL,NULL,'UNUSED',NULL,0,1630430255);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query19"

query20="REPLACE INTO access VALUES('kTCCServiceUbiquity','/System/Library/PrivateFrameworks/Tourist.framework/Versions/A/Resources/touristd',1,2,5,1,NULL,NULL,NULL,'UNUSED',NULL,0,1630430262);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query20"

query21="REPLACE INTO access VALUES('kTCCServiceUbiquity','/System/Library/PrivateFrameworks/PhotoLibraryServices.framework/Versions/A/Support/photolibraryd',1,2,5,1,NULL,NULL,NULL,'UNUSED',NULL,0,1677514715);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query21"

query22="REPLACE INTO access VALUES('kTCCServiceAppleEvents','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002842);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query22"

query23="REPLACE INTO access VALUES('kTCCServiceUbiquity','com.apple.TextEdit',0,2,5,1,NULL,NULL,NULL,'UNUSED',NULL,0,1705601697);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query23"

query24="REPLACE INTO access VALUES('kTCCServiceAppleEvents','com.apple.Terminal',0,2,3,1,X'fade0c000000003000000001000000060000000200000012636f6d2e6170706c652e5465726d696e616c000000000003',NULL,0,'com.apple.systemevents',X'fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003',NULL,1705601803);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query24"

query25="REPLACE INTO access VALUES('kTCCServiceAppleEvents','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'com.apple.systemevents',X'fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003',1,1705601845);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query25"

query26="REPLACE INTO access VALUES('kTCCServiceAppleEvents','/usr/libexec/sshd-keygen-wrapper',1,2,3,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'com.apple.systemevents',X'fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003',NULL,1705603240);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query26"
