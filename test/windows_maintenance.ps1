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
$caption = (Get-CimInstance Win32_OperatingSystem).Caption
$release = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').ReleaseId
$needsTask = $caption -match 'Windows (10|11)' -and $release -in @('2004', '2009')
$paths = @($root, "$root\ronin", "$root\semaphore")
if ($needsTask) { $paths += "$root\disable_win_defend" }
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

$tasks = @(Get-ScheduledTask | Where-Object TaskName -eq 'disable_windows_defender')
if (!$needsTask) {
    if ($tasks.Count -ne 0) { throw 'Unexpected Defender task on this OS.' }
}
else {
    if ($tasks.Count -ne 1) { throw 'Expected one Defender task.' }
    $task = $tasks[0]
    if (!$task.Settings.Enabled -or $task.Principal.UserId -notin @('SYSTEM', 'S-1-5-18')) {
        throw 'The Defender task must be enabled and run as SYSTEM.'
    }
    $actions = @($task.Actions)
    $system32 = "$env:SystemRoot\System32"
    if ($actions.Count -ne 1 -or
        $actions[0].Execute -ne "$system32\WindowsPowerShell\v1.0\powershell.exe" -or
        $actions[0].WorkingDirectory -ne $system32 -or
        $actions[0].Arguments -ne "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$root\disable_win_defend\DisableWindowsDefender.ps1`"") {
        throw 'Unexpected Defender task action.'
    }
    $triggers = @($task.Triggers)
    if ($triggers.Count -ne 1 -or $triggers[0].CimClass.CimClassName -ne 'MSFT_TaskBootTrigger' -or !$triggers[0].Enabled) {
        throw 'The Defender task must run at boot.'
    }
    foreach ($name in @('DisableWindowsDefender.ps1', 'OwnRegistryKeys.ps1',
                       'DisableWindowsDefenderfeatures.reg', 'DisableWindowsDefenderobjects.reg',
                       'DisableWindowsDefenderservices.reg')) {
        $path = "$root\disable_win_defend\$name"
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing file: $path" }
        $acl = Get-Acl -LiteralPath $path
        if ($acl.GetOwner([System.Security.Principal.SecurityIdentifier]).Value -notin @('S-1-5-18', 'S-1-5-32-544')) {
            throw "Unexpected file owner: $path"
        }
        $rules = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
        if ($rules.Count -ne $expected.Count) { throw "Unexpected file permissions: $path" }
        foreach ($rule in $rules) {
            if ($rule.AccessControlType -ne 'Allow' -or
                $rule.FileSystemRights -ne $expected[$rule.IdentityReference.Value] -or
                !$rule.IsInherited) {
                throw "Unexpected file access rule: $path"
            }
        }
    }
}
Write-Output 'Windows maintenance checks passed.'
