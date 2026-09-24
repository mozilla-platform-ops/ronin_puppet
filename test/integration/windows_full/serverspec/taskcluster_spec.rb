require_relative 'spec_helper'

expected_nssm_version = expected_hiera_value('nssm', 'version')
expected_taskcluster_version = expected_hiera_value('taskcluster', 'version')

describe file("C:\\nssm\\nssm-#{expected_nssm_version}\\win64\\nssm.exe") do
  it { should exist }
end

describe powershell_command("(Get-Service 'worker-runner' -ErrorAction Stop).Name") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^worker-runner\s*$/) }
end

describe powershell_command("(Get-Acl 'C:\\worker-runner\\runner.yml').GetOwner([System.Security.Principal.SecurityIdentifier]).Value") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^S-1-5-18\s*$/) }
end

describe powershell_command(<<~POWERSHELL) do
  $paths = @{
    'C:\\generic-worker' = @('S-1-5-18', 'S-1-5-32-544', 'S-1-5-32-545')
    'C:\\generic-worker\\generic-worker.exe' = @('S-1-5-18', 'S-1-5-32-544', 'S-1-5-32-545')
    'C:\\generic-worker\\taskcluster-proxy.exe' = @('S-1-5-18', 'S-1-5-32-544', 'S-1-5-32-545')
    'C:\\generic-worker\\task-user-init.ps1' = @('S-1-5-18', 'S-1-5-32-544', 'S-1-5-32-545')
    'C:\\worker-runner' = @('S-1-5-18', 'S-1-5-32-544')
    'C:\\worker-runner\\start-worker.exe' = @('S-1-5-18', 'S-1-5-32-544')
  }
  foreach ($path in $paths.Keys) {
    $acl = Get-Acl -LiteralPath $path -ErrorAction Stop
    if ($path -in @('C:\\generic-worker', 'C:\\worker-runner') -and !$acl.AreAccessRulesProtected) {
      throw "Inherited directory ACL: $path"
    }
    $rules = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
    if ($rules.Count -ne $paths[$path].Count) { throw "Unexpected ACL: $path" }
    foreach ($rule in $rules) {
      $sid = $rule.IdentityReference.Value
      $rights = if ($sid -eq 'S-1-5-32-545') {
        [System.Security.AccessControl.FileSystemRights]::ReadAndExecute -bor [System.Security.AccessControl.FileSystemRights]::Synchronize
      } else {
        [System.Security.AccessControl.FileSystemRights]::FullControl
      }
      if ($sid -notin $paths[$path] -or $rule.AccessControlType -ne 'Allow' -or $rule.FileSystemRights -ne $rights) {
        throw "Unexpected ACL entry on ${path}: $rule"
      }
    }
  }
  'Worker ACLs passed'
POWERSHELL
  its(:exit_status) { should eq 0 }
  its(:stdout) { should include('Worker ACLs passed') }
end

{
  'C:\\generic-worker\\generic-worker.exe' => 'generic-worker',
  'C:\\worker-runner\\start-worker.exe' => 'worker-runner',
  'C:\\generic-worker\\taskcluster-proxy.exe' => 'taskcluster-proxy',
  'C:\\generic-worker\\livelog.exe' => 'livelog'
}.each do |path, _label|
  describe file(path) do
    it { should exist }
  end

  describe powershell_command(<<~POWERSHELL) do
    $version = & '#{path}' --short-version 2>$null
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $version
  POWERSHELL
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match(/^#{Regexp.escape(expected_taskcluster_version)}\s*$/) }
  end
end
