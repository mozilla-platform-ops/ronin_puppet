Vagrant.configure("2") do |config|

  config.vm.define "bionic", autostart: false do |bionic|
    bionic.vm.box = "ubuntu/bionic64"
    bionic.vm.provision "shell", inline: <<-SHELL
        echo Adding puppetlabs ppa ...
        curl -s -O https://apt.puppetlabs.com/puppet6-release-bionic.deb
        dpkg -i puppet6-release-bionic.deb
        apt-get update
        echo Installing Puppet Agent ...
        apt-get -y install puppet-agent=6.0.0-1bionic
        echo Installing r10k ...
        /opt/puppetlabs/puppet/bin/gem install r10k -v 3.0.3
        ln -s /opt/puppetlabs/puppet/bin/r10k /opt/puppetlabs/bin/r10k
    SHELL
  end

  config.vm.define "mojave", autostart: false do |mojave|
    mojave.vm.box = "macinbox"
    mojave.vm.synced_folder ".", "/Users/vagrant/vagrant", type: "rsync", owner: "vagrant", group: "staff", create: true
    mojave.vm.provision "shell", inline: <<-SHELL
        echo Downloading Puppet Agent ...
        curl -s -O https://downloads.puppetlabs.com/mac/puppet6/10.13/x86_64/puppet-agent-6.2.0-1.osx10.13.dmg
        echo Mounting dmg ...
        sudo hdiutil mount puppet-agent-6.2.0-1.osx10.13.dmg
        echo Installing Puppet Agent
        sudo installer -pkg /Volumes/puppet-agent-6.2.0-1.osx10.13/puppet-agent-6.2.0-1-installer.pkg -target /
        echo Ejecting dmg ...
        sudo hdiutil eject /Volumes/puppet-agent-6.2.0-1.osx10.13
        echo Installing r10k
        sudo /opt/puppetlabs/puppet/bin/gem install r10k -v 3.0.3
        sudo ln -s /opt/puppetlabs/puppet/bin/r10k /opt/puppetlabs/bin/r10k
    SHELL
  end

end
