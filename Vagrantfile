$script = <<-SCRIPT
echo Adding puppetlabs ppa
curl -s -O https://apt.puppetlabs.com/puppet6-release-bionic.deb
dpkg -i puppet6-release-bionic.deb
apt-get update
echo Installing puppet6
apt-get -y install puppet-agent=6.0.0-1bionic
echo Installing r10k
/opt/puppetlabs/puppet/bin/gem install r10k -v 3.0.3
ln -s /opt/puppetlabs/puppet/bin/r10k /opt/puppetlabs/bin/r10k
SCRIPT


Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/bionic64"
  config.vm.provision "shell", inline: $script
end
