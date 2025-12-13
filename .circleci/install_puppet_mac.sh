#!/usr/bin/env bash

set -e

# PUPPET_VER="<< parameters.puppet_version >>"
# BOLT_VER="<< parameters.bolt_version >>"

# determine architecture
ARCH=$(uname -m)
echo "Architecture is ${ARCH}"

# if on arm64
if [ "${ARCH}" = "arm64" ]; then
    echo "Installing puppet agent for arm64 architecture"

    # Install openvox puppet agent
    curl -s -O "https://downloads.voxpupuli.org/mac/openvox8/openvox-agent-8.24.1-1.macos.all.arm64.dmg"
    hdiutil mount "openvox-agent-8.24.1-1.macos.all.arm64.dmg"
    sudo -E installer -pkg "/Volumes/openvox-agent-8.24.1/openvox-agent-8.24.1-1-installer.pkg" -target /

    # Install bolt
    # - no openvox build yet
    curl -s -O "https://downloads.puppet.com/mac/puppet-tools/12/x86_64/puppet-bolt-4.0.0-1.osx12.dmg"
    hdiutil mount puppet-bolt-4.0.0-1.osx12.dmg
    sudo -E installer -pkg "/Volumes/puppet-bolt-4.0.0-1.osx12/puppet-bolt-4.0.0-1-installer.pkg" -target /

    # Install gems needed for hiera vault
    sudo /opt/puppetlabs/puppet/bin/gem install vault -v 0.18.2
    sudo /opt/puppetlabs/puppet/bin/gem install debouncer
# if on x86_64
elif [ "${ARCH}" = "x86_64" ]; then
    echo "Installing puppet agent for x86_64 architecture"

    # Install puppet agent
    curl -s -O "https://downloads.puppet.com/mac/puppet/${OS_VER}/arm64/puppet-agent-${PUPPET_VER}-1.osx${OS_VER}.dmg"
    # TODO: use https://downloads.voxpupuli.org/mac/openvox8/14/x86_64/unsigned/openvox-agent-8.19.2-1.osx14.dmg
    hdiutil mount "puppet-agent-${PUPPET_VER}-1.osx${OS_VER}.dmg"
    sudo -E installer -pkg "/Volumes/puppet-agent-${PUPPET_VER}-1.osx${OS_VER}/puppet-agent-${PUPPET_VER}-1-installer.pkg" -target /

    # Install gems needed for hiera vault
    sudo /opt/puppetlabs/puppet/bin/gem install vault -v 0.18.2
    sudo /opt/puppetlabs/puppet/bin/gem install debouncer
fi
