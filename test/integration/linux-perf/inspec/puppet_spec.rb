require_relative 'spec_helper'


# most 'puppet' testing moved to openvox_spec.rb

# ensure puppet-agent isn't set to run
describe service('puppet') do
  it { should_not be_enabled }
end

describe package('puppet-release') do
  it { should_not be_installed }
end


## /etc/puppet/ronin_settings
# TODO: move this to a differently named file, since it's not really puppet-specific, but more of a general ronin config file

# verify run-puppet service and script
describe service('run-puppet') do
  it { should be_enabled }
end

describe file('/etc/puppet/ronin_settings.example') do
  it { should exist }
end

# /usr/local/bin/changetype.py
describe file('/usr/local/bin/change_workertype.py') do
  it { should exist }
  it { should be_executable }
end
