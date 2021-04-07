require_relative 'spec_helper'

describe file('/etc/systemd/system/papertrail.service') do
  # test that systemd config is in place
  it { should exist }
  # verify that systemd unit file has proper entries/format
  it { should contain 'ExecStart=/bin/sh -c "journalctl -u check_gw -u generic-worker -u run-puppet -u run-start-worker -u sudo -u ssh  -f | ncat --ssl localhost 1111"' }
end

# service is enabled
describe service('papertrail') do
  it { should be_enabled }
end

# nmap/ncat is installed
describe package('nmap') do
  it { should be_installed }
end
