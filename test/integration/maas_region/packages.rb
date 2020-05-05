# require 'spec_helper.rb'

describe package('maas-region-controller'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end