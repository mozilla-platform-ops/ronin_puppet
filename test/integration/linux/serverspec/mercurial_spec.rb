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
