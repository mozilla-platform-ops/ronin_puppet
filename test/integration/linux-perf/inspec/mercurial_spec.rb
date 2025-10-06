require_relative 'spec_helper'

# describe package('mercurial'), :if => os[:family] == 'ubuntu' do
#   it { should be_installed }
# end

describe file('/etc/mercurial/hgrc.d/mozilla.rc') do
  it { should exist }
end

# check for extensions

describe file('/usr/local/lib/hgext/robustcheckout.py') do
  it { should exist }
end

# pips

# not installing py2 any longer
# describe command('pip list | grep mercurial') do
#   its(:exit_status) { should eq 0 }
#   its(:stdout) { should match /mercurial/ }
# end

describe command('pip3 list | grep mercurial') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /mercurial/ }
end

# check version
if os.family == 'debian' && os.release.start_with?('18.04')
  describe command('hg --version') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match /version 6.4.5/ }
  end
elsif os.family == 'debian' && os.release.start_with?('22.04')
  describe command('hg --version') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match /version 6.4.5/ }
  end
elsif os.family == 'debian' && os.release.start_with?('24.04')
  describe command('hg --version') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match /version 6.7.2/ }
  end
else
  # shouldn't be here
  # for other OS families or versions, show error
  describe command('false') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should_not match /NONO/ }
  end
end
