require_relative 'spec_helper'

if TASK_DRIVE == 'C:'
  describe registry_value_command('HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment', 'HG_CACHE') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^C:\\hg-cache\s*$/) }
  end

  describe registry_value_command('HKLM:\\SOFTWARE\\Mozilla\\ronin_puppet', 'task_drive') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^C:\s*$/) }
  end

  describe registry_value_command('HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management', 'PagingFiles') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^C:\\pagefile\.sys 8192 8192\s*$/) }
    its(:stdout) { should_not match(/D:\\/i) }
  end

  { 'tasks' => 'Users', 'caches' => 'caches', 'downloads' => 'downloads' }.each do |setting, directory|
    describe file('C:\\worker-runner\\runner.yml') do
      its(:content) { should match(/^\s+#{setting}Dir: 'C:\\#{directory}'\s*$/) }
    end
  end

  describe file('C:\\hg-shared') do
    it { should be_directory }
  end

  describe powershell_command(<<~POWERSHELL) do
    $acl = Get-Acl -LiteralPath 'C:\\hg-shared' -ErrorAction Stop
    $acl.GetOwner([System.Security.Principal.SecurityIdentifier]).Value
    $acl.Access | Where-Object {
      $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value -eq 'S-1-1-0' -and
      $_.AccessControlType -eq 'Allow' -and
      ($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::FullControl) -eq [System.Security.AccessControl.FileSystemRights]::FullControl -and
      ($_.InheritanceFlags -band 3) -eq 3
    } | ForEach-Object { 'task-users-inherit-full-control' }
  POWERSHELL
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^S-1-5-18\s*$/) }
    its(:stdout) { should match(/^task-users-inherit-full-control\s*$/) }
  end

end
