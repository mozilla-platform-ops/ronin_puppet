require_relative 'spec_helper'


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
end

if os.family == 'ubuntu' && os.release == '22.04'
  describe package('python3.10-minimal') do
    it { should be_installed }
  end

  describe file('/usr/bin/python3.10') do
    it { should exist }
    it { should be_executable }
  end

  describe command('/usr/bin/python3.10 -c "import distutils"') do
    its(:exit_status) { should eq 0 }
  end

  # config files

  describe file('/home/cltbld/.pip/pip.conf') do
    it { should exist }
  end

  # ensure pip check returns 0 for all pythons

  # linked to python3.10
  describe command('python -m pip check') do
    its(:exit_status) { should eq 0 }
  end

  # system provided 3.10
  describe command('python3 -m pip check') do
    its(:exit_status) { should eq 0 }
  end

  describe command('/usr/bin/python3 --version') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match /Python 3.10/ }
  end
end