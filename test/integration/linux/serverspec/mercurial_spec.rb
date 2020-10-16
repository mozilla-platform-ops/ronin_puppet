require_relative 'spec_helper'

describe package('mercurial'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

# check for extensions

describe file('/usr/local/lib/hgext/robustcheckout.py') do
  it { should exist }
end

describe file('/usr/local/lib/hgext/bundleclone.py') do
  it { should exist }
end

# pips

# TODO: check versions

describe command('pip list | grep zstandard') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /mercurial/ }
end

describe command('pip3 list | grep zstandard') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /mercurial/ }
end
