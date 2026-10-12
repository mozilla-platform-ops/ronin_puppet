# Run on a configured Windows worker with Windows PowerShell 5.1:
# powershell.exe -NoProfile -File test/windows_maintenance.ps1
# These checks do not change the worker.
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:ProgramData 'PuppetLabs\ronin'
$expected = @{
  'S-1-5-18' = [System.Security.AccessControl.FileSystemRights]::FullControl
  'S-1-5-32-544' = [System.Security.AccessControl.FileSystemRights]::FullControl
  'S-1-5-32-545' = [System.Security.AccessControl.FileSystemRights]::ReadAndExecute -bor [System.Security.AccessControl.FileSystemRights]::Synchronize
}
$paths = @($root, "$root\ronin", "$root\semaphore")
foreach ($path in $paths) {
  $acl = Get-Acl -LiteralPath $path
  if (!$acl.AreAccessRulesProtected) { throw "Inherited permissions: $path" }
  if ($acl.GetOwner([System.Security.Principal.SecurityIdentifier]).Value -ne 'S-1-5-18') {
    throw "Unexpected owner: $path"
  }
  $rules = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
  if ($rules.Count -ne $expected.Count) { throw "Unexpected permissions: $path" }
  foreach ($rule in $rules) {
    if ($rule.AccessControlType -ne 'Allow' -or
        $rule.FileSystemRights -ne $expected[$rule.IdentityReference.Value] -or
        $rule.InheritanceFlags -ne 'ContainerInherit, ObjectInherit' -or
        $rule.PropagationFlags -ne 'None') {
      throw "Unexpected access rule: $path"
    }
  }
}

Write-Output 'Windows maintenance directory checks passed.'
