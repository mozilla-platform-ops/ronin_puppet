require_relative 'spec_helper'

describe file('/usr/local/bin/git') do
  it { should exist }
  it { should be_file }
  it { should be_mode 755 }
end

describe command('/usr/local/bin/git --version') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/2\.47\.1/) }
end
