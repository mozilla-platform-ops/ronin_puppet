require_relative 'spec_helper'

describe package('maas-rack-controller'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end
