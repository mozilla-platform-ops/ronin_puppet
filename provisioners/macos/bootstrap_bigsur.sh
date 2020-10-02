#!/bin/bash

PUPPET_REPO=${PUPPET_REPO:-"https://github.com/davehouse/ronin_puppet.git"}
PUPPET_BRANCH=${PUPPET_BRANCH:-"bug1667424_macos-bigsur"}
PUPPET_ROLE=${PUPPET_ROLE:-"gecko_t_osx_1100"}

macos_version="11.00.0"
git_version="2.27.0"  # 2020-07-22
puppet_version="6.18.0-1"  # 2020-08-25


declare -i screenshotcounter=0
screenshot_filename_base=/tmp/screenshot_bootstrap_$(date +"%Y-%m-%d-%H:%M:%S")
function screenshot() {
  filename="${screenshot_filename_base}_${screenshotcounter}_$(date +"%H:%M:%S").jpg"
  screencapture -x $filename
  chmod ugo+r $filename
  screenshotcounter+=1
}

function fail {
    echo "${@}"
    date
    echo "[sleep 120 ...]"
    screenshot
    sleep 120
    exit 1
}


# Check base system state
host=$(scutil --get ComputerName)
echo $host

ioreg -l | grep IOPlatformSerialNumber

ifconfig | grep -v "127.0.0.1\|169." | grep -C4 "inet [0-9]\+\.[0-9]\+"

sw_vers

/usr/sbin/nvram -p

# Print config
sudo systemsetup $(sudo systemsetup -help | grep -o '\-get[^ ]*')
# Turn off power savings/etc
sudo systemsetup \
    -setsleep Never \
    -setrestartpowerfailure on \
    -setwakeonnetworkaccess on \
    -setallowpowerbuttontosleepcomputer off \
    -setrestartfreeze on

# Enable ssh
sudo systemsetup -setremotelogin on

# SIP check
# ensure ssh and no power-savings before failing on this
if csrutil status | grep -q "enabled"; then
   fail "SIP is enabled!"
fi

# Check for find-my-mac
fmm_computer_name=$(nvram fmm-computer-name 2>/dev/null | cut -d$'\t' -f2)
fmm_mobileme_token_FMM=$(nvram fmm-mobileme-token-FMM 2>/dev/null | cut -d$'\t' -f2)
if [[ -n "${fmm_mobileme_token_FMM}" ]]; then
    echo "fmm-computer-name= ${fmm_computer_name}"
    echo "fmm-mobileme-token-FMM= ${fmm_mobileme_token_FMM}"
    fail "Find-my-mac is enabled!?"
fi

# Ensure no fingerprints are stored for login
fingerprints=$(declare -i count=0;\
  while read -r line; do count+=$line; done \
  <<<$(bioutil -c | grep -o '[0-9]\+ fingerprint' | cut -d\  -f1); echo $count)
[[ $fingerprints == 0 ]] \
  && echo "No fingerprints." \
  || fail "Fingerprints stored!"

screenshot


# Install pre-reqs for puppet run

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

[[ $git_version == $(git --version | cut -d\  -f3) ]] \
  && git --version \
  || install "https://downloads.sourceforge.net/project/git-osx-installer/git-${git_version}-intel-universal-mavericks.dmg" \
    7a828be2ea16ad48797157769d29028f2d1c0040c87525467fd5addbb11a2cac \
    || fail "git install failed"

[[ "${puppet_version%%-*}" == $(puppet --version) ]] \
  && printf "puppet version %s\n" $(puppet --version) \
  || install "https://downloads.puppetlabs.com/mac/puppet/10.15/x86_64/puppet-agent-${puppet_version}.osx10.14.dmg" \
    b8ffdb76613adac062dea5be6ccfab8d310fd4c203396a28614f6c62f56f4deb \
    || fail "puppet install failed"

screenshot


# Run puppet

PUPPET_FORK="${PUPPET_REPO%.git}"
PUPPET_FORK="${PUPPET_FORK#*.com}"
PUPPET_REPO_BUNDLE="https://raw.githubusercontent.com${PUPPET_FORK}/${PUPPET_BRANCH}/provisioners/macos/bootstrap_mojave.sh"
curl --silent -L -O "${PUPPET_REPO_BUNDLE}"

echo $PUPPET_ROLE > /etc/puppet_role
cat /etc/puppet_role

export PUPPET_REPO
export PUPPET_BRANCH
sed -i.bak '/reboot/d' ./bootstrap_mojave.sh
bash bootstrap_mojave.sh \
  && echo Success \
  || fail "Puppet failed!?"


# Review setup/prompts for test-runner user
sudo -u cltbld defaults read com.apple.SetupAssistant

# Power savings stayed off?
if ! (sudo systemsetup -getsleep | grep Computer | grep Never); then
  fail "Power saving need to be turned off."
fi

# Software updates are turned off?
if ! (sudo softwareupdate --schedule | grep 'Automatic check is off'); then
  fail "Software updates are turned on."
fi

# Check if configured for iCloud
if grep -i account /Users/*/Library/Preferences/MobileMeAccounts.plist \
    2>/dev/null; then
  fail "iCloud is configured"
fi
icloud_status=$(brctl status 2>&1)
if [[ $icloud_status == *"iCloud Drive is not configured"* \
   || $icloud_status == *"com.apple.bird was invalidated"* ]]; then
  echo "iCloud is disabled: $icloud_status"
fi

# Install Intel Power Gadget (also in puppet. this checks sha)
# 3.5.5 https://software.intel.com/sites/default/files/managed/16/90/Intel%20Power%20Gadget.dmg
#   PowerLog 9210e37554afc4449dcd3896aa6c9a884b20f0788e75ed2dcfae79f294b2d151 \
#   dmg efd306800c28abda0d5543fbc5bf78eb142a43a96feb56fcf211e3bbc83a78d3
# 3.6.1 https://software.intel.com/sites/default/files/managed/16/90/Intel%20Power%20Gadget.dmg
#   PowerLog 15ac1c8ca6a99bb4856cb9e1a06293c4f088875741b46cc8a3246a453405143d
#   dmg f88af78566e406a06bf96349a7314a811cedfa698b38252ffc36f4f19ab52b65
# 3.7.0 https://software.intel.com/content/dam/develop/external/us/en/documents/Intel-Power-Gadget-v3.7.0.dmg
#   dmg 22ed3fe050c3b965841ccc5590a3a03bb9498f8620e01ba4dea5557dcd24fe43
checksum "/Applications/Intel Power Gadget/PowerLog" \
  9210e37554afc4449dcd3896aa6c9a884b20f0788e75ed2dcfae79f294b2d151 \
  || install "https://ronin-puppet-package-repo.s3-us-west-2.amazonaws.com/macos/public/common/Intel_Power_Gadget_3.7.0.dmg" \
    22ed3fe050c3b965841ccc5590a3a03bb9498f8620e01ba4dea5557dcd24fe43 \
  && (
    sudo kextutil /Library/Extensions/EnergyDriver.kext
    sudo kextload /Library/Extensions/EnergyDriver.kext
    sudo spctl kext-consent status
    /Applications/Intel\ Power\ Gadget/PowerLog -resolution 1000 -file /dev/stdout -cmd "for I in {1..3}; do sleep 1; done"
  ) \
    || fail "intel power gadget install failed"

screenshot

if [[ $(sw_vers -productVersion) != "${macos_version}" ]]; then
  fail "Please upgrade to MacOS ${macos_version}."
  echo "https://updates.cdn-apple.com/2019/macos/041-94408-20190801-a9bffb44-63dd-4972-ac53-a76ee3d7924d/macOSUpd10.14.6.dmg"
fi
