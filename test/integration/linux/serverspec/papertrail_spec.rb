require_relative 'spec_helper'

# test that systemd config is in place
describe file('/etc/systemd/system/papertrail.service') do
  it { should exist }
end

# service is enabled
describe service('papertrail') do
  it { should be_enabled }
end

# nmap/ncat is installed
describe package('nmap') do
  it { should be_installed }
end
