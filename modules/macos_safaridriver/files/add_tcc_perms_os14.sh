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
query="REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'UNUSED',NULL,0,1710355061,NULL,NULL,'UNUSED',1710355061);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query"

query1="REPLACE INTO access VALUES('kTCCServiceAccessibility','com.apple.Terminal',0,2,4,1,X'fade0c000000003000000001000000060000000200000012636f6d2e6170706c652e5465726d696e616c000000000003',NULL,0,'UNUSED',NULL,0,1710355518,NULL,NULL,'UNUSED',1710355518);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query1"

query2="REPLACE INTO access VALUES('kTCCServiceAccessibility','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'UNUSED',NULL,0,1710355823,NULL,NULL,'UNUSED',1710355823);"
sudo sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" "$query2"

# kTCCServiceAppleEvents, in user TCC DB


query3="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.transparencyd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354891,NULL,NULL,'UNUSED',1710354891);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query3"

query4="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.syncdefaultsd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354892,NULL,NULL,'UNUSED',1710354892);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query4"

query5="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.routined',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354893,NULL,NULL,'UNUSED',1710354893);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query5"

query6="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.imagent',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354898,NULL,NULL,'UNUSED',1710354898);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query6"

query7="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.assistant.assistantd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354898,NULL,NULL,'UNUSED',1710354898);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query7"

query8="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.stocks',0,2,5,1,NULL,NULL,NULL,'UNUSED',NULL,0,1710354900,NULL,NULL,'UNUSED',0);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query8"

query9="REPLACE INTO access VALUES('kTCCServiceUbiquity','com.apple.stocks.detailintents',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354900,NULL,NULL,'UNUSED',1710354900);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query9"

query10="REPLACE INTO access VALUES('kTCCServiceUbiquity','com.apple.weather.widget',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354901,NULL,NULL,'UNUSED',1710354901);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query10"

query11="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.passd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354904,NULL,NULL,'UNUSED',1710354904);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query11"

query12="REPLACE INTO access VALUES('kTCCServiceLiverpool','/System/Library/PrivateFrameworks/UsageTracking.framework/Versions/A/UsageTrackingAgent',1,2,5,1,NULL,NULL,NULL,'UNUSED',NULL,0,1710354911,NULL,NULL,'UNUSED',0);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query12"

query13="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.triald',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354918,NULL,NULL,'UNUSED',1710354918);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query13"

query14="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.voicebankingd',0,0,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354921,NULL,NULL,'UNUSED',1710354921);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query14"

query15="REPLACE INTO access VALUES('kTCCServiceLiverpool','/System/Library/PrivateFrameworks/TextToSpeechVoiceBankingSupport.framework/Support/voicebankingd',1,2,5,1,NULL,NULL,NULL,'UNUSED',NULL,0,1710354922,NULL,NULL,'UNUSED',0);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query15"

query16="REPLACE INTO access VALUES('kTCCServiceUbiquity','com.apple.weather',0,2,5,1,NULL,NULL,NULL,'UNUSED',NULL,0,1710354933,NULL,NULL,'UNUSED',0);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query16"

query17="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.securityd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354936,NULL,NULL,'UNUSED',1710354936);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query17"

query18="REPLACE INTO access VALUES('kTCCServiceUbiquity','com.apple.finder',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355042,NULL,NULL,'UNUSED',1710355042);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query18"

query19="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.willowd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query19"

query20="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.avatarsd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query20"

query21="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.callhistory.sync-helper',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query21"

query22="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.donotdisturbd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query22"

query23="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.knowledge-agent',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query23"

query24="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.amsengagementd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query24"

query25="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.identityservicesd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query25"

query26="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.icloud.searchpartyuseragent',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query26"

query27="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.findmy.findmylocateagent',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query27"

query28="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.appleaccountd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query28"

query29="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.icloud.fmfd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query29"

query30="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.StatusKitAgent',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query30"

query31="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.shortcuts',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query31"

query32="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.Passbook',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query32"

query33="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.siriknowledged',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query33"

query34="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.suggestd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query34"

query35="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.Safari',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query35"

query36="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.sociallayerd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355044);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query36"

query37="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.UsageTrackingAgent',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355045,NULL,NULL,'UNUSED',1710355045);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query37"

query38="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.cloudpaird',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355050,NULL,NULL,'UNUSED',1710355050);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query38"

query39="REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.textinput.KeyboardServices',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355067,NULL,NULL,'UNUSED',1710355067);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query39"

query40="REPLACE INTO access VALUES('kTCCServiceSystemPolicyDesktopFolder','com.apple.Terminal',0,2,2,1,X'fade0c000000003000000001000000060000000200000012636f6d2e6170706c652e5465726d696e616c000000000003',NULL,NULL,'UNUSED',NULL,0,1710355245,NULL,NULL,'UNUSED',0);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query40"

query41="REPLACE INTO access VALUES('kTCCServiceUbiquity','com.apple.Safari',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355252,NULL,NULL,'UNUSED',1710355252);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query41"

query42="REPLACE INTO access VALUES('kTCCServiceUbiquity','com.apple.identityservicesd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355435,NULL,NULL,'UNUSED',1710355435);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query42"

query43="REPLACE INTO access VALUES('kTCCServiceUbiquity','com.apple.imagent',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355437,NULL,NULL,'UNUSED',1710355437);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query43"

query44="REPLACE INTO access VALUES('kTCCServiceAppleEvents','com.apple.Terminal',0,2,3,1,X'fade0c000000003000000001000000060000000200000012636f6d2e6170706c652e5465726d696e616c000000000003',NULL,0,'com.apple.systemevents',X'fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003',NULL,1710355505,NULL,NULL,'UNUSED',1710355505);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query44"

query45="REPLACE INTO access VALUES('kTCCServiceAppleEvents','/usr/libexec/sshd-keygen-wrapper',1,2,3,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'com.apple.systemevents',X'fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003',NULL,1710355814,NULL,NULL,'UNUSED',1710355814);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query45"
