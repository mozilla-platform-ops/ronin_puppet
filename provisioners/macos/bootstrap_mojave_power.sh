#!/bin/bash

PUPPET_REPO=${PUPPET_REPO:-"https://github.com/mozilla-platform-ops/ronin_puppet.git"}
PUPPET_BRANCH=${PUPPET_BRANCH:-"master"}
PUPPET_ROLE=${PUPPET_ROLE:-"bitbar_mbp"}

function fail {
    echo "${@}"
    date
    echo "[sleep 120 ...]"
    sleep 120
    exit 1
}

host=$(scutil --get ComputerName)
echo $host

echo $PUPPET_ROLE > /etc/puppet_role
cat /etc/puppet_role

declare -i screenshotcounter=0
function screenshot() {
  filename="~relops/screenshot_bootstrap_${screenshotcounter}_$(date +"%Y-%m-%d-%H:%M:%S").jpg"
  screencapture -x $filename
  chown relops $filename
  chmod ugo+r $filename
  screenshotcounter+=1
}
screenshot

ioreg -l | grep IOPlatformSerialNumber

if csrutil status | grep -q "enabled"; then
   fail "SIP is enabled!"
fi

ifconfig|grep -v "127.0.0.1\|169."|grep -C4 "inet [0-9]\+\.[0-9]\+"

# Enable ssh
sudo systemsetup -setremotelogin on

# Print config
sudo systemsetup $(sudo systemsetup -help | grep -o '\-get[^ ]*')
# Turn off power savings/etc
sudo systemsetup \
    -setsleep Never \
    -setrestartpowerfailure on \
    -setwakeonnetworkaccess on \
    -setallowpowerbuttontosleepcomputer off \
    -setrestartfreeze on

# Ensure no fingerprints are stored for login
fingerprints=$(declare -i count=0;\
  while read -r line; do count+=$line; done \
  <<<$(bioutil -c | grep -o '[0-9]\+ fingerprint' | cut -d\  -f1); echo $count)
[[ $fingerprints == 0 ]] \
  && echo "No fingerprints." \
  || fail "Fingerprints stored!"

function checksum() {
  sum=$(shasum -a 256 "$1" 2>/dev/null || openssl dgst -sha256 "$1" 2>/dev/null)
  [[ "${sum%% *}" == "$2" ]]
}

function install() {
  dmg_url=$1
  md5=$2
  dmg="${dmg_url##*\/}"
  checksum $dmg $md5 \
    || curl -L -O $dmg_url
  if ! checksum $dmg $md5; then
    echo "${dmg} checksum does not match ${md5}"
    return 1
  fi
  while IFS=' ' read -r mnt path; do
    sudo installer -target / -pkg ${path}/*pkg
    hdiutil unmount -force -whole -notimeout $mnt
  done < <(hdiutil mount -plist -nobrowse -readonly -noidme -mountrandom /tmp "$dmg" | grep '\(\/dev\/disk.s\|\/private\/tmp\)' | sed -e 's/.*>\([^<]*\)<.*/\1/' | tr $'\n' ' '; echo); 
}

# See http://apple.stackexchange.com/questions/107307/how-can-i-install-the-command-line-tools-completely-from-the-command-line
xcode-select -p &> /dev/null
if [ $? -ne 0 ]; then
  echo "Xcode CLI tools not found. Installing them..."
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress;
  PROD=$(softwareupdate -l |
    grep "\*.*Command Line" |
    head -n 1 | awk -F"*" '{print $2}' |
    sed -e 's/^ *//' |
    tr -d '\n')
  softwareupdate -i "$PROD" --verbose \
    || fail "Xcode CLI tools install failed"
else
  echo "Xcode CLI tools OK"
fi

[[ "2.21.0" == $(git --version | cut -d\  -f3) ]] \
  && git --version \
  || install "https://downloads.sourceforge.net/project/git-osx-installer/git-2.21.0-intel-universal-mavericks.dmg" \
    7a828be2ea16ad48797157769d29028f2d1c0040c87525467fd5addbb11a2cac \
    || fail "git install failed"

[[ "6.3.0" == $(puppet --version) ]] \
  && printf "puppet version %s\n" $(puppet --version) \
  || install "https://downloads.puppetlabs.com/mac/puppet/10.14/x86_64/puppet-agent-6.3.0-1.osx10.14.dmg" \
    b8ffdb76613adac062dea5be6ccfab8d310fd4c203396a28614f6c62f56f4deb \
    || fail "puppet install failed"

checksum "/Applications/Intel Power Gadget/PowerLog" \
  9210e37554afc4449dcd3896aa6c9a884b20f0788e75ed2dcfae79f294b2d151 \
  || install "https://software.intel.com/sites/default/files/managed/34/fb/Intel%C2%AE%20Power%20Gadget.dmg" \
    efd306800c28abda0d5543fbc5bf78eb142a43a96feb56fcf211e3bbc83a78d3 \
  && (
    sudo kextutil /Library/Extensions/EnergyDriver.kext
    sudo kextload /Library/Extensions/EnergyDriver.kext
    sudo spctl kext-consent status
    /Applications/Intel\ Power\ Gadget/PowerLog -resolution 1000 -file /dev/stdout -cmd "for I in {1..3}; do sleep 1; done"
  ) \
    || fail "intel power gadget install failed"

screenshot

PUPPET_FORK="${PUPPET_REPO%.git}"
PUPPET_FORK="${PUPPET_FORK#*.com}"
PUPPET_REPO_BUNDLE="https://raw.githubusercontent.com${PUPPET_FORK}/${PUPPET_BRANCH}/provisioners/macos/bootstrap_mojave.sh"
curl -L -O "${PUPPET_REPO_BUNDLE}"

export PUPPET_REPO
export PUPPET_BRANCH
sed -i.bak '/reboot/d' ./bootstrap_mojave.sh
bash bootstrap_mojave.sh \
  && echo Success \
  || fail "Puppet failed!?"

screenshot
