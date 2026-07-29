require_relative 'spec_helper'

describe file('/etc/sudoers') do
  its(:content) { should match /%admin\sALL=\(ALL\)\sNOPASSWD:\sALL/ }
  its(:content) { should match %r{cltbld ALL=\(root\) NOPASSWD: /usr/local/bin/set-intel-pstate-perf-pct} }
end

describe file('/usr/local/bin/set-intel-pstate-perf-pct') do
  it { should exist }
  it { should be_executable }
  its('owner') { should eq 'root' }
  its('group') { should eq 'root' }
end
