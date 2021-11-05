require_relative 'spec_helper'

describe package('ubuntu-desktop'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end
