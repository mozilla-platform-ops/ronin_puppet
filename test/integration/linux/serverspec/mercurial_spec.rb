require_relative 'spec_helper'

describe package('mercurial'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe file('/etc/mercurial/hgrc.d/mozilla.rc') do
  it { should exist }
end

# check for extensions

describe file('/usr/local/lib/hgext/robustcheckout.py') do
  it { should exist }
end

# pips

# TODO: check versions

describe command('pip list | grep mercurial') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /mercurial/ }
end

# disabled until we're on mercurial 5/py3 compatible version
# describe command('pip3 list | grep mercurial') do
#   its(:exit_status) { should eq 0 }
#   its(:stdout) { should match /mercurial/ }
# end
