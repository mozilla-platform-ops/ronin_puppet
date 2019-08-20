#!/bin/bash

PUPPET_REPO=${PUPPET_REPO:-"https://github.com/mozilla-platform-ops/ronin_puppet.git"}
PUPPET_BRANCH=${PUPPET_BRANCH:-"master"}

host=$(scutil --get ComputerName)
echo $host

declare -i screenshotcounter=0
function screenshot() {
  screencapture -x ~/screenshot_bootstrap_${screenshotcounter}.jpg
  screenshotcounter+=1
}
screenshot

ioreg -l | grep IOPlatformSerialNumber

if csrutil status | grep -q "enabled"; then
   echo "SIP is enabled!"
fi

ifconfig|grep -v "127.0.0.1\|169."|grep -C4 "inet [0-9]\+\.[0-9]\+"

echo "bitbar_mbp" > /etc/puppet_role

sudo systemsetup -setremotelogin on

sudo systemsetup $(sudo systemsetup -help | grep -o '\-get[^ ]*')

sudo systemsetup -setsleep Never -setrestartpowerfailure on -setwakeonnetworkaccess on -setallowpowerbuttontosleepcomputer off -setrestartfreeze on


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

[[ "2.21.0" == $(git --version | cut -d\  -f3) ]] \
  && git --version \
  || install "https://downloads.sourceforge.net/project/git-osx-installer/git-2.21.0-intel-universal-mavericks.dmg" \
    7a828be2ea16ad48797157769d29028f2d1c0040c87525467fd5addbb11a2cac
  
[[ "6.3.0" == $(puppet --version) ]] \
  && printf "puppet version %s\n" $(puppet --version) \
  || install "https://downloads.puppetlabs.com/mac/puppet/10.14/x86_64/puppet-agent-6.3.0-1.osx10.14.dmg" \
    b8ffdb76613adac062dea5be6ccfab8d310fd4c203396a28614f6c62f56f4deb

checksum "/Applications/Intel Power Gadget/PowerLog" \
  9210e37554afc4449dcd3896aa6c9a884b20f0788e75ed2dcfae79f294b2d151 \
  || \
  install "https://software.intel.com/sites/default/files/managed/34/fb/Intel%C2%AE%20Power%20Gadget.dmg" \
    efd306800c28abda0d5543fbc5bf78eb142a43a96feb56fcf211e3bbc83a78d3 \
  && (
    sudo kextutil /Library/Extensions/EnergyDriver.kext
    sudo kextload /Library/Extensions/EnergyDriver.kext
    sudo spctl kext-consent status
    /Applications/Intel\ Power\ Gadget/PowerLog -resolution 1000 -file /dev/stdout -cmd "for I in {1..3}; do sleep 1; done"
  )

PUPPET_FORK="${PUPPET_REPO%.git}"
PUPPET_FORK="${PUPPET_FORK#*.com}"
PUPPET_REPO_BUNDLE="https://raw.githubusercontent.com${PUPPET_FORK}/${PUPPET_BRANCH}/provisioners/macos/bootstrap_mojave.sh"
curl -L -O "${PUPPET_REPO_BUNDLE}"

export PUPPET_REPO
export PUPPET_BRANCH

screenshot
sed -i.bak '/reboot/d' ./bootstrap_mojave.sh
bash bootstrap_mojave.sh && echo Success

screenshot
