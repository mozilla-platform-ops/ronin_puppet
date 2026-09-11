require_relative 'spec_helper'

describe file('/usr/local/bin/record-system-perf') do
  it { should be_owned_by 'root' }
  it { should be_mode 755 }
end

describe file('/var/lib/record-system-perf') do
  it { should be_directory }
  it { should be_owned_by 'root' }
  it { should be_mode 700 }
end

describe file('/etc/sudoers') do
  its(:content) { should match /cltbld\sALL=\(root\)\sNOPASSWD:\s\/usr\/local\/bin\/record-system-perf ""/ }
  # Retained until the Raptor caller migration is deployed.
  its(:content) { should match /cltbld\sALL=\(root\)\sNOPASSWD:\s\/usr\/bin\/perf/ }
end
