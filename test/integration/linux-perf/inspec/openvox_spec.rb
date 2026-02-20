require_relative 'spec_helper'

# openvox: puppet replacement

describe package('openvox-agent'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
  # TODO: check with with_version('/6.*/') when available
  # - available with inspec (https://docs.chef.io/inspec/resources/package/#version-1)
end

# openvox-agent conflicts with puppet-agent, ensure it's not installed
describe package('puppet-agent'), :if => os[:family] == 'ubuntu' do
  it { should_not be_installed }
end

if os.family == 'debian' && (os.release.start_with?('18.04') or os.release.start_with?('22.04') or os.release.start_with?('24.04'))
  describe package('openvox8-release'), :if => os[:family] == 'ubuntu' do
    it { should be_installed }
  end

  describe file('/etc/apt/sources.list.d/openvox8-release.list'), :if => os[:family] == 'ubuntu' do
    it { should exist }
  end
else
  # shouldn't be here
  # for other OS families or versions, show error
  describe command('false') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should_not match /NONO/ }
  end
end
