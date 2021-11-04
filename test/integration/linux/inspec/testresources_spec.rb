require_relative 'spec_helper'

describe package('python-testresources'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe package('python3-testresources'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end
