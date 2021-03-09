require_relative 'spec_helper'

# py3.6

describe package('python3.6-minimal'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe file('/usr/bin/python3.6') do
  it { should exist }
  it { should be_executable }
end

# py3.9

describe package('python3.9-minimal'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe file('/usr/bin/python3.9') do
  it { should exist }
  it { should be_executable }
end
