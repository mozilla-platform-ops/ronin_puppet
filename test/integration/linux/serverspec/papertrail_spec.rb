require_relative 'spec_helper'

# systemd unit files are in place with proper content
describe file('/etc/systemd/system/papertrail.service') do
  it { should exist }
  it { should contain 'ExecStart=/bin/sh -c "journalctl -u check_gw -u run-puppet -u ssh  -f | ncat --ssl localhost 1111"' }
end

describe file('/etc/systemd/system/papertrail-syslog.service') do
  it { should exist }
  it { should contain 'ExecStart=/bin/sh -c "journalctl -t generic-worker -t run-start-worker -t sudo  -f | ncat --ssl localhost 1111"' }
end

# services are enabled
describe service('papertrail') do
  it { should be_enabled }
end

describe service('papertrail-syslog') do
  it { should be_enabled }
end

# nmap/ncat is installed
describe package('nmap') do
  it { should be_installed }
end
