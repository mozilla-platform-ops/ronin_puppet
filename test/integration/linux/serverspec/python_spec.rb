require_relative 'spec_helper'

# py3.6

describe package('python3.6-minimal'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe file('/usr/bin/python3.6') do
  it { should exist }
  it { should be_executable }
end

# py3.8

describe package('python3.8-minimal'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe file('/usr/bin/python3.8') do
  it { should exist }
  it { should be_executable }
end

describe command('/usr/bin/python3.8 -c "import distutils"') do
  its(:exit_status) { should eq 0 }
end

# py3.9

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

# config files

describe file('/etc/pip.conf') do
  it { should exist }
end

describe file('/home/cltbld/.pip/pip.conf') do
  it { should exist }
end
