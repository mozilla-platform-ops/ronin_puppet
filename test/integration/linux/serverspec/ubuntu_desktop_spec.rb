# require 'spec_helper.rb'

describe package('ubuntu-desktop'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end