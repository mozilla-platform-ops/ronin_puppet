require_relative 'spec_helper'

current_version_key = 'HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion'

{
  'ProductName' => 'Windows Server 2025 Datacenter Azure Edition',
  'DisplayVersion' => '24H2',
  'ReleaseId' => '2009',
  'CurrentBuild' => '26100',
  'InstallationType' => 'Server Core'
}.each do |property, expected|
  describe registry_value_command(current_version_key, property) do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^#{Regexp.escape(expected)}\s*$/) }
  end
end

describe registry_value_command('HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System', 'EnableLUA') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^0\s*$/) }
end

describe file('C:\\mozilla-build') do
  it { should be_directory }
end

describe file('C:\\generic-worker\\task-user-init.cmd') do
  it { should be_file }
end
