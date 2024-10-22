require_relative 'spec_helper'

describe package('puppet-agent'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
  # TODO: check with with_version('/6.*/') when available
  # - available with inspec (https://docs.chef.io/inspec/resources/package/#version-1)
end

describe package('puppet7-release'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

# verify run-puppet service and script
describe service('run-puppet') do
  it { should be_enabled }
end

## not enabled/present

# ensure puppet-agent isn't set to run
describe service('puppet') do
  it { should_not be_enabled }
end

describe package('puppet-release') do
  it { should_not be_installed }
end

## /etc/puppet/ronin_settings

describe file('/etc/puppet/ronin_settings.example') do
  it { should exist }
end

# /usr/local/bin/changetype.py
describe file('/usr/local/bin/change_workertype.py') do
  it { should exist }
  it { should be_executable }
end
