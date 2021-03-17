require_relative 'spec_helper'

# disabled services

describe service('anacron') do
  it { should_not be_enabled }
end

describe service('apport') do
  it { should_not be_enabled }
end

describe file('/etc/default/apport') do
  it { should contain 'enabled=0' }
end

describe service('avahi-daemon') do
  it { should_not be_enabled }
end

describe service('cups') do
  it { should_not be_enabled }
end

describe service('modemmanager') do
  it { should_not be_enabled }
end

describe service('network-manager') do
  it { should_not be_enabled }
end

describe service('whoopsie') do
  it { should_not be_enabled }
end

# services that require disabled services (also need to be stopped)

describe service('NetworkManager-wait-online') do
  it { should_not be_enabled }
end

describe service('cups-browsed') do
  it { should_not be_enabled }
end

# bluez packages, but bluetooth service
describe service('bluetooth') do
  it { should_not be_enabled }
end

# check that apt automated actions are disabled

describe file('/etc/apt/apt.conf.d/10periodic') do
  it { should contain 'APT::Periodic::Enable "0";' }
  it { should contain 'APT::Periodic::Update-Package-Lists "0";' }
  it { should contain 'APT::Periodic::Download-Upgradeable-Packages "0";' }
  it { should contain 'APT::Periodic::AutocleanInterval "0";' }
end

describe file('/etc/apt/apt.conf.d/20auto-upgrades') do
  it { should contain 'APT::Periodic::Update-Package-Lists "0";' }
  it { should contain 'APT::Periodic::Unattended-Upgrade "0";' }
end
