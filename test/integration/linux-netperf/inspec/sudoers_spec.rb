require_relative 'spec_helper'

# cltbld can run the netperf traffic-control wrapper without a password
describe file('/etc/sudoers') do
  its(:content) { should match /cltbld\sALL=\(root\)\sNOPASSWD:\s\/usr\/local\/bin\/netperf-tc/ }
  its(:content) { should_not match /cltbld\sALL=\(ALL\)\sNOPASSWD:\s\/sbin\/tc/ }
end

describe file('/usr/local/bin/netperf-tc') do
  it { should exist }
  it { should be_owned_by 'root' }
  its('mode') { should cmp '0755' }
end
