require_relative 'spec_helper'

describe package('iperf3'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe command('iperf3 --version') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /iperf 3/ }
end
