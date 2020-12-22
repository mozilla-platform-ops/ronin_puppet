require_relative 'spec_helper'

describe package('puppet-agent'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
  # TODO: check with with_version('/6.*/') when available
  # - available with inspec (https://docs.chef.io/inspec/resources/package/#version-1)
end

describe package('puppet-release'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

# TODO: verify atboot service and script
