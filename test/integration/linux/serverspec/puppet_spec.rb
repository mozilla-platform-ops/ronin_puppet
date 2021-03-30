require_relative 'spec_helper'

describe package('puppet-agent'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
  # TODO: check with with_version('/6.*/') when available
  # - available with inspec (https://docs.chef.io/inspec/resources/package/#version-1)
end

describe package('puppet-release'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

# verify run-puppet service and script
describe service('run-puppet') do
  it { should be_enabled }
end

# ensure puppet-agent isn't set to run
describe service('puppet') do
  it { should_not be_enabled }
end
