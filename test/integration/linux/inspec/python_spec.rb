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

describe command('python3.8 -m pip check') do
  its(:exit_status) { should eq 0 }
end

describe command('python3.9 -m pip check') do
  its(:exit_status) { should eq 0 }
end

# ensure /usr/bin/python3 is py3.9

describe command('/usr/bin/python3') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /Python 3.9/ }
end
