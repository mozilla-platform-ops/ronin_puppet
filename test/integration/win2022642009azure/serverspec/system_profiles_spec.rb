require_relative 'spec_helper'

error_reporting_key = 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\Windows Error Reporting'
file_system_key = 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\FileSystem'
network_window_key = 'HKLM:\\System\\CurrentControlSet\\Control\\Network\\NewNetworkWindowOff'
explorer_policy_key = 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Explorer'
push_notifications_key = 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\CurrentVersion\\PushNotifications'
uac_key = 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System'

describe file('D:\\') do
  it { should exist }
  it { should be_directory }
end

describe powershell_command(<<~POWERSHELL) do
  $dump_folder = Get-ItemPropertyValue -Path '#{error_reporting_key}' -Name 'DumpFolder' -ErrorAction Stop
  if (-not (Test-Path $dump_folder)) { exit 1 }
  $dump_folder
POWERSHELL
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^[A-Z]:\\error-dumps\s*$/i) }
end

{
  'LocalDumps' => '1',
  'DontShowUI' => '1'
}.each do |name, expected|
  describe registry_value_command(error_reporting_key, name) do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^#{expected}\s*$/) }
  end
end

{
  'NtfsDisable8dot3NameCreation' => '1',
  'NtfsDisableLastAccessUpdate' => '2147483649'
}.each do |name, expected|
  describe registry_value_command(file_system_key, name) do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^#{expected}\s*$/) }
  end
end

describe powershell_command("(Get-NetConnectionProfile -ErrorAction Stop | Select-Object -ExpandProperty NetworkCategory -Unique) -join ','") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/Private/i) }
end

describe powershell_command("(Get-NetFirewallRule -DisplayName 'ICMP Allow incoming V4 echo request' -ErrorAction Stop | Select-Object -First 1 -ExpandProperty Enabled)") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^True\s*$/i) }
end

describe powershell_command('(Get-TimeZone -ErrorAction Stop).Id') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^UTC\s*$/) }
end

describe powershell_command('powercfg.exe /getactivescheme') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c/i) }
end

describe registry_value_command('HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Power', 'HibernateEnabled') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^0\s*$/) }
end

{
  [explorer_policy_key, 'NoNewAppAlert'] => '1',
  [explorer_policy_key, 'DisableNotificationCenter'] => '1',
  [push_notifications_key, 'NoToastApplicationNotification'] => '1',
  [uac_key, 'EnableLUA'] => '0'
}.each do |(path, name), expected|
  describe registry_value_command(path, name) do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^#{expected}\s*$/) }
  end
end

describe registry_key_exists_command(network_window_key) do
  its(:exit_status) { should eq 0 }
end

describe powershell_command(<<~POWERSHELL) do
  if (Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run' -Name 'SecurityHealth' -ErrorAction SilentlyContinue) {
    exit 1
  }
POWERSHELL
  its(:exit_status) { should eq 0 }
end
