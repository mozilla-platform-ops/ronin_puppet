require_relative 'spec_helper'

# services

describe service('acpid') do
  it { should_not be_enabled }
end

describe service('anacron') do
  it { should_not be_enabled }
end

describe service('apport') do
  it { should_not be_enabled }
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

# bluez packages, but bluetooth service
describe service('bluetooth') do
  it { should_not be_enabled }
end
