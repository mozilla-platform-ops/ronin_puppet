require_relative 'spec_helper'


#
# 18.04 checks
#
if os.family == 'ubuntu' && os.release == '18.04'
  # py3.6

  describe package('python3.6-minimal') do
    it { should be_installed }
  end

  describe file('/usr/bin/python3.6') do
    it { should exist }
    it { should be_executable }
  end

  # py3.9

  describe package('python3.9-minimal') do
    it { should be_installed }
  end

  describe file('/usr/bin/python3.9') do
    it { should exist }
    it { should be_executable }
  end

  describe command('/usr/bin/python3.9 -c "import distutils"') do
    its(:exit_status) { should eq 0 }
  end

  # config files

  describe file('/home/cltbld/.pip/pip.conf') do
    it { should exist }
  end

  # ensure pip check returns 0 for all pythons

  # system provided
  describe command('python -m pip check') do
    its(:exit_status) { should eq 0 }
  end

  # system provided 3.6
  describe command('python3 -m pip check') do
    its(:exit_status) { should eq 0 }
  end

  describe command('python3.9 -m pip check') do
    its(:exit_status) { should eq 0 }
  end
  # ensure /usr/bin/python3 is py3.9
  describe command('/usr/bin/python3 --version') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match /Python 3.9/ }
  end

  #
  # py3.9
  #
  describe package('python3.9-minimal'), :if => os[:family] == 'ubuntu' do
    it { should be_installed }
  end

  describe file('/usr/bin/python3.9') do
    it { should exist }
    it { should be_executable }
  end

  describe command('/usr/bin/python3.9 -c "import distutils"') do
    its(:exit_status) { should eq 0 }
  end

  describe command('python3.9 -m pip check') do
    its(:exit_status) { should eq 0 }
  end

  #
  # py3.6: should only be for 18.04?
  #
  describe file('/usr/bin/python3.6') do
    it { should exist }
    it { should be_executable }
  end
end

#
# config files
#
describe file('/home/cltbld/.pip/pip.conf') do
  it { should exist }
end

# ensure pip check returns 0 for all pythons

# no more py2
#
# system provided
# describe command('python -m pip check') do
#   its(:exit_status) { should eq 0 }
# end

#
# default python3 (was system provided 3.6 initially)
#
puts "DEBUG: os.family=#{os.family}, os.release=#{os.release}"

# ensure /usr/bin/python3 is correct on each os
# - ideally don't change it as it may break things
if os.family == 'debian' && os.release.start_with?('18.04')
  describe command('/usr/bin/python3 --version') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match /Python 3.11/ }
  end
elsif os.family == 'debian' && os.release.start_with?('22.04', '24.04')
  describe command('/usr/bin/python3 --version') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match /Python 3.10/ }
  end
else
  # shouldn't be here
  # for other OS families or versions, show error
  describe command('/usr/bin/python3 --version') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should_not match /NONO/ }
  end
end

# default python3 should have pip
describe command('python3 -m pip check') do
  its(:exit_status) { should eq 0 }
end
