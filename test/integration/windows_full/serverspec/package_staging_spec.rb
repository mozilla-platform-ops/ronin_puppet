require_relative 'spec_helper'

nssm_version = expected_hiera_value('nssm', 'version')
nssm_dir = expected_hiera_value('dir', 'nssm').sub('%{facts.custom_win_systemdrive}', '%SystemDrive%')
vac_dir = expected_hiera_value('dir', 'vac').sub('%{facts.custom_win_systemdrive}', '%SystemDrive%')
vac_package_dir = expected_hiera_value('vac', 'package_dir')
vac_installer = expected_hiera_value('vac', 'installer')

describe powershell_command(<<~POWERSHELL) do
  $path = Join-Path $env:SystemDrive 'RoninPackages'
  $nssmRoot = [Environment]::ExpandEnvironmentVariables('#{nssm_dir}')
  $nssmVersion = Join-Path $nssmRoot 'nssm-#{nssm_version}'
  $nssmArch = Join-Path $nssmVersion 'win64'
  $items = @(Get-Item -LiteralPath $path, $nssmRoot, $nssmVersion, $nssmArch, (Join-Path $nssmArch 'nssm.exe') -ErrorAction Stop)
  $items += @(Get-ChildItem -LiteralPath $path -File)
  $vacRoot = [Environment]::ExpandEnvironmentVariables('#{vac_dir}')
  if (Test-Path -LiteralPath $vacRoot) {
    $vacWork = Join-Path $vacRoot '#{vac_package_dir}'
    $items += @(Get-Item -LiteralPath $vacRoot, $vacWork, (Join-Path $vacWork '#{vac_installer}') -ErrorAction Stop)
  }
  $expected = @('S-1-5-18', 'S-1-5-32-544', 'S-1-5-32-545')
  foreach ($item in $items) {
    $acl = Get-Acl -LiteralPath $item.FullName -ErrorAction Stop
    if (!$acl.AreAccessRulesProtected) { throw "Inherited package staging ACL: $($item.FullName)" }
    $rules = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
    if ($rules.Count -ne $expected.Count) { throw "Unexpected package staging ACL: $($item.FullName)" }
    foreach ($rule in $rules) {
      $sid = $rule.IdentityReference.Value
      if ($sid -notin $expected -or $rule.AccessControlType -ne 'Allow') { throw "Unexpected package staging ACE: $rule" }
      if ($sid -eq 'S-1-5-32-545' -and ($rule.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::Write)) {
        throw "Users can write to $($item.FullName)"
      }
    }
  }
  'Package and extraction ACLs passed'
POWERSHELL
  its(:exit_status) { should eq 0 }
  its(:stdout) { should include('Package and extraction ACLs passed') }
end
