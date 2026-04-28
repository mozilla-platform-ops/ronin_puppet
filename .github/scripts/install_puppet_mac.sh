#!/usr/bin/env bash

set -e

OPENVOX_VERSION="8.24.1"

# determine architecture
ARCH=$(uname -m)
echo "Architecture is ${ARCH}"

if [ "${ARCH}" = "arm64" ]; then
    echo "Installing OpenVox agent for arm64 architecture"
    DMG="openvox-agent-${OPENVOX_VERSION}-1.macos.all.arm64.dmg"
elif [ "${ARCH}" = "x86_64" ]; then
    echo "Installing OpenVox agent for x86_64 architecture"
    DMG="openvox-agent-${OPENVOX_VERSION}-1.macos.all.x86_64.dmg"
else
    echo "Unsupported architecture: ${ARCH}"
    exit 1
fi

# Install OpenVox puppet agent
curl -sfO "https://downloads.voxpupuli.org/mac/openvox8/${DMG}"
hdiutil mount "${DMG}"
sudo -E installer -pkg "/Volumes/openvox-agent-${OPENVOX_VERSION}/openvox-agent-${OPENVOX_VERSION}-1-installer.pkg" -target /

# Install bolt (no OpenVox build yet, use Puppet x86_64 via Rosetta on arm64)
curl -sfO "https://downloads.puppet.com/mac/puppet-tools/12/x86_64/puppet-bolt-4.0.0-1.osx12.dmg"
hdiutil mount puppet-bolt-4.0.0-1.osx12.dmg
sudo -E installer -pkg "/Volumes/puppet-bolt-4.0.0-1.osx12/puppet-bolt-4.0.0-1-installer.pkg" -target /

# Install gems needed for hiera vault
sudo /opt/puppetlabs/puppet/bin/gem install vault -v 0.18.2
sudo /opt/puppetlabs/puppet/bin/gem install debouncer
