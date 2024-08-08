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

#!/bin/bash

# Get macOS version
os_version=$(sw_vers -productVersion)

# Function to run SQLite queries
run_query() {
    sudo sqlite3 "$1" "$2"
}

# macOS 10.15
if [[ "$os_version" == "10.15"* ]]; then
    # kTCCServiceAccessibility, in system TCC DB
    query="REPLACE INTO access VALUES('kTCCServiceAccessibility','/usr/libexec/sshd-keygen-wrapper',1,1,1,NULL,NULL,NULL,'UNUSED',NULL,0,0);"
    run_query "/Library/Application Support/com.apple.TCC/TCC.db" "$query"

    # kTCCServiceAppleEvents, in user TCC DB
    query="REPLACE INTO access VALUES('kTCCServiceAppleEvents','/usr/libexec/sshd-keygen-wrapper',1,1,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'com.apple.systemevents',X'fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003',NULL,1666043382);"
    run_query "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query"
fi

# macOS 11, 12, or 13
if [[ "$os_version" == "11."* || "$os_version" == "12."* || "$os_version" == "13."* ]]; then
    # kTCCServiceAccessibility, in system TCC DB
    query="REPLACE INTO access VALUES('kTCCServiceAccessibility','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002842);"
    run_query "/Library/Application Support/com.apple.TCC/TCC.db" "$query"

    # Other queries for macOS 11, 12, or 13
    queries=(
        "REPLACE INTO access VALUES('kTCCServiceDeveloperTool','com.apple.Terminal',0,0,4,1,NULL,NULL,0,'UNUSED',NULL,0,1630422453);"
        "REPLACE INTO access VALUES('kTCCServiceScreenCapture','com.apple.bash',0,0,6,2,X'fade0c000000002c0000000100000006000000020000000e636f6d2e6170706c652e62617368000000000003',NULL,NULL,'UNUSED',NULL,12,1630430315);"
        "REPLACE INTO access VALUES('kTCCServiceScreenCapture','/opt/homebrew/Cellar/python@3.9/3.9.5/Frameworks/Python.framework/Versions/3.9/bin/python3.9',1,0,6,2,X'fade0c00000000280000000100000008000000144ac5131b3ef95d76e8bd44eef81ba8debe1d0744',NULL,NULL,'UNUSED',NULL,12,1630430315);"
        "REPLACE INTO access VALUES('kTCCServiceScreenCapture','/opt/homebrew/Frameworks/Python.framework/Versions/3.9/bin/python3.9',1,0,6,2,X'fade0c00000000280000000100000008000000144ac5131b3ef95d76e8bd44eef81ba8debe1d0744',NULL,NULL,'UNUSED',NULL,12,1630430315);"
        "REPLACE INTO access VALUES('kTCCServiceScreenCapture','/usr/local/bin/python3',1,0,6,2,X'fade0c00000000280000000100000008000000144ac5131b3ef95d76e8bd44eef81ba8debe1d0744',NULL,NULL,'UNUSED',NULL,12,1630430315);"
        "REPLACE INTO access VALUES('kTCCServiceScreenCapture','/usr/local/bin/start-worker',1,0,6,2,X'fade0c0000000028000000010000000800000014f9da98e56dfa9c01419369e4dd43cd9d29a6f2e1',NULL,NULL,'UNUSED',NULL,12,1630430315);"
        "REPLACE INTO access VALUES('kTCCServiceScreenCapture','/usr/local/bin/generic-worker-simple',1,0,6,2,X'fade0c0000000028000000010000000800000014454b43afc7c449e66bb0014ee5329324c0c4ad3c',NULL,NULL,'UNUSED',NULL,12,1630430315);"
        "REPLACE INTO access VALUES('kTCCServicePostEvent','com.apple.screensharing.agent',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1631200687);"
        "REPLACE INTO access VALUES('kTCCServiceScreenCapture','com.apple.screensharing.agent',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1631200687);"
        "REPLACE INTO access VALUES('kTCCServiceScreenCapture','/bin/bash',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002326);"
        "REPLACE INTO access VALUES('kTCCServiceScreenCapture','com.apple.Terminal',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002339);"
        "REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002842);"
        "REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/sbin/sshd',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002869);"
        "REPLACE INTO access VALUES('kTCCServiceAccessibility','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002842);"
        "REPLACE INTO access VALUES('kTCCServiceAccessibility','/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/AE.framework/Versions/A/Support/AEServer',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705601932);"
        "REPLACE INTO access VALUES('kTCCServiceAccessibility','com.apple.Terminal',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705601934);"
        "REPLACE INTO access VALUES('kTCCServiceAppleEvents','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002842);"
        "REPLACE INTO access VALUES('kTCCServiceUbiquity','/System/Library/PrivateFrameworks/ContactsDonation.framework/Versions/A/Support/contactsdonationagent',1,2,5,1,NULL,NULL,NULL,'UNUSED',NULL,0,1630430255);"
        "REPLACE INTO access VALUES('kTCCServiceUbiquity','/System/Library/PrivateFrameworks/Tourist.framework/Versions/A/Resources/touristd',1,2,5,1,NULL,NULL,NULL,'UNUSED',NULL,0,1630430262);"
        "REPLACE INTO access VALUES('kTCCServiceUbiquity','/System/Library/PrivateFrameworks/PhotoLibraryServices.framework/Versions/A/Support/photolibraryd',1,2,5,1,NULL,NULL,NULL,'UNUSED',NULL,0,1677514715);"
        "REPLACE INTO access VALUES('kTCCServiceAppleEvents','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1705002842);"
        "REPLACE INTO access VALUES('kTCCServiceUbiquity','com.apple.TextEdit',0,2,5,1,NULL,NULL,NULL,'UNUSED',NULL,0,1705601697);"
        "REPLACE INTO access VALUES('kTCCServiceAppleEvents','com.apple.Terminal',0,2,3,1,X'fade0c000000003000000001000000060000000200000012636f6d2e6170706c652e5465726d696e616c000000000003',NULL,0,'com.apple.systemevents',X'fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003',NULL,1705601803);"
        "REPLACE INTO access VALUES('kTCCServiceAppleEvents','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'com.apple.systemevents',X'fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003',1,1705601845);"
        "REPLACE INTO access VALUES('kTCCServiceAppleEvents','/usr/libexec/sshd-keygen-wrapper',1,2,3,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'com.apple.systemevents',X'fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003',NULL,1705603240);"
    )
    for query in "${queries[@]}"; do
        run_query "/Library/Application Support/com.apple.TCC/TCC.db" "$query"
    done
fi

# macOS 14
if [[ "$os_version" == "14."* ]]; then
    # kTCCServiceSystemPolicyAllFiles, in system TCC DB
    query="REPLACE INTO access VALUES('kTCCServiceSystemPolicyAllFiles','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'UNUSED',NULL,0,1710355061,NULL,NULL,'UNUSED',1710355061);"
    run_query "/Library/Application Support/com.apple.TCC/TCC.db" "$query"

    # Other queries for macOS 14
    queries=(
        "REPLACE INTO access VALUES('kTCCServiceAccessibility','com.apple.Terminal',0,2,4,1,X'fade0c000000003000000001000000060000000200000012636f6d2e6170706c652e5465726d696e616c000000000003',NULL,0,'UNUSED',NULL,0,1710355518,NULL,NULL,'UNUSED',1710355518);"
        "REPLACE INTO access VALUES('kTCCServiceAccessibility','/usr/libexec/sshd-keygen-wrapper',1,2,4,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'UNUSED',NULL,0,1710355823,NULL,NULL,'UNUSED',1710355823);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.transparencyd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354891,NULL,NULL,'UNUSED',1710354891);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.syncdefaultsd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354892,NULL,NULL,'UNUSED',1710354892);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.routined',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354893,NULL,NULL,'UNUSED',1710354893);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.imagent',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354898,NULL,NULL,'UNUSED',1710354898);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.assistant.assistantd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354898,NULL,NULL,'UNUSED',1710354898);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.stocks',0,2,5,1,NULL,NULL,NULL,'UNUSED',NULL,0,1710354900,NULL,NULL,'UNUSED',0);"
        "REPLACE INTO access VALUES('kTCCServiceUbiquity','com.apple.stocks.detailintents',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354900,NULL,NULL,'UNUSED',1710354900);"
        "REPLACE INTO access VALUES('kTCCServiceUbiquity','com.apple.weather.widget',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354901,NULL,NULL,'UNUSED',1710354901);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.passd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354904,NULL,NULL,'UNUSED',1710354904);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','/System/Library/PrivateFrameworks/UsageTracking.framework/Versions/A/UsageTrackingAgent',1,2,5,1,NULL,NULL,NULL,'UNUSED',NULL,0,1710354911,NULL,NULL,'UNUSED',0);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.triald',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354918,NULL,NULL,'UNUSED',1710354918);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.voicebankingd',0,0,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354921,NULL,NULL,'UNUSED',1710354921);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','/System/Library/PrivateFrameworks/TextToSpeechVoiceBankingSupport.framework/Support/voicebankingd',1,2,5,1,NULL,NULL,NULL,'UNUSED',NULL,0,1710354922,NULL,NULL,'UNUSED',0);"
        "REPLACE INTO access VALUES('kTCCServiceUbiquity','com.apple.weather',0,2,5,1,NULL,NULL,NULL,'UNUSED',NULL,0,1710354933,NULL,NULL,'UNUSED',0);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.securityd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710354936,NULL,NULL,'UNUSED',1710354936);"
        "REPLACE INTO access VALUES('kTCCServiceUbiquity','com.apple.finder',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355042,NULL,NULL,'UNUSED',1710355042);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.willowd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.avatarsd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.callhistory.sync-helper',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.donotdisturbd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.knowledge-agent',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.amsengagementd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.identityservicesd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.icloud.searchpartyuseragent',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.findmy.findmylocateagent',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.appleaccountd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.icloud.fmfd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.StatusKitAgent',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.shortcuts',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.Passbook',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.siriknowledged',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.suggestd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.Safari',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355043);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.sociallayerd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355043,NULL,NULL,'UNUSED',1710355044);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.UsageTrackingAgent',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355045,NULL,NULL,'UNUSED',1710355045);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.cloudpaird',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355050,NULL,NULL,'UNUSED',1710355050);"
        "REPLACE INTO access VALUES('kTCCServiceLiverpool','com.apple.textinput.KeyboardServices',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355067,NULL,NULL,'UNUSED',1710355067);"
        "REPLACE INTO access VALUES('kTCCServiceSystemPolicyDesktopFolder','com.apple.Terminal',0,2,2,1,X'fade0c000000003000000001000000060000000200000012636f6d2e6170706c652e5465726d696e616c000000000003',NULL,NULL,'UNUSED',NULL,0,1710355245,NULL,NULL,'UNUSED',0);"
        "REPLACE INTO access VALUES('kTCCServiceUbiquity','com.apple.Safari',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355252,NULL,NULL,'UNUSED',1710355252);"
        "REPLACE INTO access VALUES('kTCCServiceUbiquity','com.apple.identityservicesd',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355435,NULL,NULL,'UNUSED',1710355435);"
        "REPLACE INTO access VALUES('kTCCServiceUbiquity','com.apple.imagent',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,1710355437,NULL,NULL,'UNUSED',1710355437);"
        "REPLACE INTO access VALUES('kTCCServiceAppleEvents','com.apple.Terminal',0,2,3,1,X'fade0c000000003000000001000000060000000200000012636f6d2e6170706c652e5465726d696e616c000000000003',NULL,0,'com.apple.systemevents',X'fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003',NULL,1710355505,NULL,NULL,'UNUSED',1710355505);"
        "REPLACE INTO access VALUES('kTCCServiceAppleEvents','/usr/libexec/sshd-keygen-wrapper',1,2,3,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'com.apple.systemevents',X'fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003',NULL,1710355814,NULL,NULL,'UNUSED',1710355814);"
    )
    for query in "${queries[@]}"; do
        run_query "/Library/Application Support/com.apple.TCC/TCC.db" "$query"
    done
fi
