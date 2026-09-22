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

foreach ($file in Get-ChildItem -LiteralPath $source -Filter '*.reg') {
    foreach ($line in Get-Content -LiteralPath $file.FullName) {
        if ($line.StartsWith('[')) {
            Assert ($line -match '^\[-?HKEY_LOCAL_MACHINE\\[^\]]+\]$') "Invalid registry entry: $line"
        }
    }
}

$env:SystemRoot = 'C:\Windows'
$env:ProgramFiles = 'C:\Program Files'
${env:ProgramFiles(x86)} = 'C:\Program Files (x86)'
$env:ProgramData = 'C:\ProgramData'
$commands = [System.Collections.Generic.List[object]]::new()
$renames = [System.Collections.Generic.List[string]]::new()
function Get-Process { param($Name, $ErrorAction) if ($running) { 'MsMpEng' } }
function Test-Path { param($LiteralPath) !$missing }
function Rename-Item {
    param($LiteralPath, $NewName)
    $renames.Add("$LiteralPath -> $NewName")
}
function Invoke-CheckedCommand {
    param([string] $Path, [string[]] $Arguments)
    Assert ($Path.StartsWith("$env:SystemRoot\System32\")) 'Executable path must be absolute.'
    if ($Path.EndsWith('powershell.exe')) {
        Assert ($Arguments[4] -eq '-File') 'Registry helper must run with -File.'
        Assert (Microsoft.PowerShell.Management\Test-Path -LiteralPath $Arguments[5]) 'Registry helper must use its full path.'
        Assert (Microsoft.PowerShell.Management\Test-Path -LiteralPath $Arguments[6]) 'Registry data must use its full path.'
    }
    $commands.Add(@{ Path = $Path; Arguments = $Arguments })
    if ($failImport -and $Path.EndsWith('reg.exe')) { throw 'Import failed' }
}

foreach ($running in @($true, $false)) {
    foreach ($missing in @($false, $true)) {
        $commands.Clear()
        $renames.Clear()
        Disable-WindowsDefender | Out-Null
        $imports = @($commands | Where-Object { $_.Path.EndsWith('reg.exe') })
        if ($running) {
            Assert ($imports.Count -eq 1) 'Running Defender must only import object settings.'
            Assert ($imports[0].Arguments[1].EndsWith('objects.reg')) 'Wrong registry phase.'
            $expectedCommands = if ($missing) { 2 } else { 8 }
        }
        else {
            Assert ($imports.Count -eq 2) 'Stopped Defender must import features and services.'
            Assert ($imports[0].Arguments[1].EndsWith('features.reg')) 'Features must be imported first.'
            Assert ($imports[1].Arguments[1].EndsWith('services.reg')) 'Services must be imported second.'
            $expectedCommands = 4
        }
        Assert ($commands.Count -eq $expectedCommands) 'Wrong command count.'
        $expectedRenames = if ($missing) { 0 } else { 3 }
        Assert ($renames.Count -eq $expectedRenames) 'Missing paths must be skipped.'
    }
}

$running = $false
$missing = $false
$failImport = $true
$renames.Clear()
$failed = $false
try { Disable-WindowsDefender | Out-Null }
catch { $failed = $_.Exception.Message -eq 'Import failed' }
Assert $failed 'Import failure must reach the caller.'
Assert ($renames.Count -eq 0) 'Do not rename directories after an import failure.'
Write-Output 'Windows Defender script checks passed.'
