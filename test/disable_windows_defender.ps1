# Run with: pwsh -NoProfile -File test/disable_windows_defender.ps1
# Windows commands are replaced below; this test does not change the host.
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '../modules/win_disable_services/files/windows_defender'
. (Join-Path $source 'DisableWindowsDefender.ps1')

function Assert($Condition, [string] $Message) {
    if (!$Condition) { throw $Message }
}

# Check actual process exit handling before replacing Windows commands.
$shell = (Get-Process -Id $PID).Path
Invoke-CheckedCommand $shell @('-NoProfile', '-NonInteractive', '-Command', 'exit 0')
$failed = $false
try { Invoke-CheckedCommand $shell @('-NoProfile', '-NonInteractive', '-Command', 'exit 7') }
catch { $failed = $_.Exception.Message -like '*exit code 7' }
Assert $failed 'A failed command must stop execution.'

# This fixture records the operations from the original .reg files.
$expected = Get-Content (Join-Path $PSScriptRoot 'fixtures/windows_defender_registry.json') -Raw | ConvertFrom-Json
$env:SystemRoot = 'C:\Windows'
$env:ProgramFiles = 'C:\Program Files'
${env:ProgramFiles(x86)} = 'C:\Program Files (x86)'
$env:ProgramData = 'C:\ProgramData'
$commands = [System.Collections.Generic.List[object]]::new()
$renames = [System.Collections.Generic.List[string]]::new()
$deletions = [System.Collections.Generic.List[string]]::new()
$writtenValues = [System.Collections.Generic.List[string]]::new()
$created = [System.Collections.Generic.List[string]]::new()
$owned = [System.Collections.Generic.HashSet[string]]::new()
function Get-Process { param($Name, $ErrorAction) if ($running) { 'MsMpEng' } }
function Test-Path { param($LiteralPath) !$missing }
function Rename-Item {
    param($LiteralPath, $NewName)
    $renames.Add("$LiteralPath -> $NewName")
}
function Invoke-CheckedCommand {
    param([string] $Path, [string[]] $Arguments)
    Assert ($Path -in @("$env:SystemRoot\System32\takeown.exe", "$env:SystemRoot\System32\icacls.exe")) 'Unexpected executable.'
    $commands.Add(@{ Path = $Path; Arguments = $Arguments })
}
function ownRegistryKey {
    param($keyName)
    if ($failure -eq 'owner') { Write-Error 'Registry failure' }
    [void]$owned.Add("Registry::$keyName")
}
function Remove-Item {
    param($LiteralPath, [switch]$Recurse, [switch]$Force)
    Assert ($owned.Contains($LiteralPath)) 'Take ownership before deleting a key.'
    Assert $Recurse 'Delete the complete registry subtree.'
    if ($failure -eq 'delete') { Write-Error 'Registry failure' }
    $deletions.Add($LiteralPath.Replace('Registry::', ''))
}
function New-Item {
    param($Path, [switch]$Force)
    Assert $missing 'Do not recreate existing keys.'
    Assert ($owned.Contains($Path)) 'Request ownership before creating a key.'
    if ($failure -eq 'create') { Write-Error 'Registry failure' }
    $created.Add($Path)
}
function New-ItemProperty {
    param($LiteralPath, $Name, $PropertyType, $Value, [switch]$Force)
    Assert ($owned.Contains($LiteralPath)) 'Take ownership before setting values.'
    Assert ($PropertyType -eq 'DWord') 'Preserve the registry value type.'
    Assert $Force 'Update existing values.'
    if ($missing) { Assert ($created.Contains($LiteralPath)) 'Create missing keys before setting values.' }
    if ($failure -eq 'write') { Write-Error 'Registry failure' }
    $writtenValues.Add("$($LiteralPath.Replace('Registry::', ''))|$Name|$Value")
}

foreach ($running in @($true, $false)) {
    foreach ($missing in @($false, $true)) {
        $commands.Clear()
        $renames.Clear()
        $deletions.Clear()
        $writtenValues.Clear()
        $created.Clear()
        $owned.Clear()
        Disable-WindowsDefender | Out-Null
        if ($running) {
            $expectedDeletions = if ($missing) { @() } else { @($expected.deletions) }
            Assert ((($deletions | Sort-Object) -join "`n") -eq (($expectedDeletions | Sort-Object) -join "`n")) 'Registry deletions must match the original entries.'
            Assert ($writtenValues.Count -eq 0) 'Do not set feature or service values while Defender runs.'
            Assert ($created.Count -eq 0) 'Do not create keys while deleting objects.'
            $expectedCommands = if ($missing) { 0 } else { 6 }
        }
        else {
            $expectedValues = $expected.values | ForEach-Object { "$($_.key)|$($_.name)|$($_.value)" }
            Assert ((($writtenValues | Sort-Object) -join "`n") -eq (($expectedValues | Sort-Object) -join "`n")) 'Registry values must match the original entries.'
            Assert ($deletions.Count -eq 0) 'Do not delete objects in the feature and service phase.'
            $expectedCreated = if ($missing) { 23 } else { 0 }
            Assert ($created.Count -eq $expectedCreated) 'Create only missing registry keys.'
            $expectedCommands = 0
        }
        Assert ($commands.Count -eq $expectedCommands) 'Wrong command count.'
        $expectedRenames = if ($missing) { 0 } else { 3 }
        Assert ($renames.Count -eq $expectedRenames) 'Missing paths must be skipped.'
    }
}

foreach ($failure in 'owner', 'delete', 'create', 'write') {
    $running = $failure -eq 'delete'
    $missing = $failure -eq 'create'
    $renames.Clear()
    $deletions.Clear()
    $writtenValues.Clear()
    $failed = $false
    try { Disable-WindowsDefender | Out-Null }
    catch { $failed = $_.Exception.Message -eq 'Registry failure' }
    Assert $failed "Registry $failure failure must reach the caller."
    Assert ($deletions.Count -eq 0 -and $writtenValues.Count -eq 0) 'Stop registry changes after a failure.'
    if (!$running) { Assert ($renames.Count -eq 0) 'Do not rename directories after a registry failure.' }
}
Write-Output 'Windows Defender script checks passed.'
