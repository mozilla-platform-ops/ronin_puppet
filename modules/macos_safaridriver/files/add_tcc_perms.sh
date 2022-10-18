#!/usr/bin/env bash

set -e
# set -x

if [ "$USER" != "root" ]; then
    echo "must run as root!"
    exit 1
fi

# tool_path="/tmp"

# accessibility
# TESTING: are these even needed?
# python ${tool_path}/tccutil.py -i /usr/sbin/sshd
# python ${tool_path}/tccutil.py -i /usr/libexec/sshd-keygen-wrapper
# python ${tool_path}/tccutil.py -i /usr/bin/osascript
# python ${tool_path}/tccutil.py -i com.apple.Terminal

# applescript, in user TCC db
#   - not using tccutil due to funky binary data
query="INSERT INTO access VALUES('kTCCServiceAppleEvents','/usr/libexec/sshd-keygen-wrapper',1,1,1,X'fade0c000000003c0000000100000006000000020000001d636f6d2e6170706c652e737368642d6b657967656e2d7772617070657200000000000003',NULL,0,'com.apple.systemevents',X'fade0c000000003400000001000000060000000200000016636f6d2e6170706c652e73797374656d6576656e7473000000000003',NULL,1666043382);"
sudo sqlite3 "/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db" "$query"
