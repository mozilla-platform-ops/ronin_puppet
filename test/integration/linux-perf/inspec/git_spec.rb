require_relative 'spec_helper'

describe package('git'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe command('git --version') do
    its('stdout') { should eq "git version 2.42.0\n" }
    its('exit_status') { should eq 0 }
end
