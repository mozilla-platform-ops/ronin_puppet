require_relative 'spec_helper'

windows_update_key = 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate'
windows_update_au_key = "#{windows_update_key}\\AU"
clipboard_service_key = 'HKLM:\\SYSTEM\\CurrentControlSet\\Services\\cbdhsvc'
clipboard_key = 'HKLM:\\SOFTWARE\\Microsoft\\Clipboard'
task_script_dir = 'C:\\ProgramData\\PuppetLabs\\ronin'
tester_role = WORKER_FUNCTION == 'tester'

{
  'puppet' => {
    'State' => 'Stopped',
    'StartMode' => 'Disabled'
  },
  'DiagTrack' => {
    'State' => 'Stopped',
    'StartMode' => 'Disabled'
  }
}.tap do |service_checks|
  service_checks['WSearch'] = {
    'State' => 'Stopped',
    'StartMode' => 'Disabled'
  } if tester_role

  service_checks.each do |service_name, properties|
    properties.each do |property, expected|
      describe service_property_command(service_name, property) do
        its(:exit_status) { should eq 0 }
        its(:stdout) { should match(/^#{Regexp.escape(expected)}\s*$/i) }
      end
    end
  end
end

{
  ['HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\DriverSearching', 'SearchOrderConfig'] => '0',
  [windows_update_au_key, 'AUOptions'] => '1',
  [windows_update_au_key, 'NoAutoUpdate'] => '1',
  [windows_update_key, 'DoNotConnectToWindowsUpdateInternetLocations'] => '1',
  [windows_update_key, 'DisableWindowsUpdateAccess'] => '1',
  ['HKLM:\\SYSTEM\\CurrentControlSet\\Services\\wuauserv', 'Start'] => '4',
  ['HKLM:\\SYSTEM\\CurrentControlSet\\Services\\WaaSMedicSvc', 'Start'] => '4',
  ['HKLM:\\SYSTEM\\CurrentControlSet\\Services\\DoSvc', 'Start'] => '4'
}.each do |(path, name), expected|
  describe registry_value_command(path, name) do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^#{expected}\s*$/) }
  end
end

[
  ['disable_wu', 'disable_wu_task.ps1'],
  ['at_task_user_logon', 'at_task_user_logon.ps1'],
  ['maintain_system', 'maintainsystem.ps1']
].tap do |task_checks|
  task_checks << ['kill_remote_clipboard', 'kill_local_clipboard.ps1'] if tester_role

  task_checks.each do |task_name, script_name|
    describe scheduled_task_command(task_name, '$task.Settings.Enabled') do
      its(:exit_status) { should eq 0 }
      its(:stdout) { should match(/^True\s*$/i) }
    end

    describe scheduled_task_command(task_name, '$task.Principal.UserId') do
      its(:exit_status) { should eq 0 }
      its(:stdout) { should match(/^SYSTEM\s*$/i) }
    end

    describe scheduled_task_command(task_name, '$task.Actions | Select-Object -First 1 | Select-Object -ExpandProperty Execute') do
      its(:exit_status) { should eq 0 }
      its(:stdout) { should match(/powershell\.exe\s*$/i) }
    end

    describe scheduled_task_command(task_name, '$task.Actions | Select-Object -First 1 | Select-Object -ExpandProperty Arguments') do
      its(:exit_status) { should eq 0 }
      its(:stdout) { should match(/#{Regexp.escape("#{task_script_dir}\\#{script_name}")}/i) }
    end
  end
end

if tester_role
  {
    [clipboard_service_key, 'Start'] => '4',
    [clipboard_service_key, 'UserServiceFlags'] => '0',
    [clipboard_key, 'EnableClipboardHistory'] => '0'
  }.each do |(path, name), expected|
    describe registry_value_command(path, name) do
      its(:exit_status) { should eq 0 }
      its(:stdout) { should match(/^#{expected}\s*$/) }
    end
  end
end

describe software_property_command("$_.DisplayName -eq 'NXLog-CE'", 'DisplayVersion') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^2\.10\.2150(?:\.\d+)?\s*$/) }
end

describe file('C:\\Program Files (x86)\\nxlog\\conf\\nxlog.conf') do
  it { should exist }
end

describe service_property_command('nxlog', 'State') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^Running\s*$/i) }
end
