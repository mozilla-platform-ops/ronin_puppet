$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$path = Join-Path $PSScriptRoot '../../modules/win_scheduled_tasks/files/azure-maintainsystem.ps1'
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
foreach ($name in @('Complete-AzurePuppetRun', 'Assert-AzureGpuReady')) {
    $fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true)
    . ([scriptblock]::Create($fn.Extent.Text))
}
function Write-Log { param($message, $severity) }
function Set-ItemProperty { param($Path, $Name, $Value, $ErrorAction) $script:registry[$Name] = $Value }
function Remove-Item { param($LiteralPath, $ErrorAction) }
function Move-Item { param($LiteralPath, $Destination, [switch]$Force, $ErrorAction) $script:forwarded = $true }
function shutdown.exe { $script:reboot = $true }
function Get-CimInstance { param($ClassName, $ErrorAction) return $script:controllers }
foreach ($code in @(0, 2, 1, 4, 6)) {
    foreach ($pool in @('win11-64-24h2-alpha', 'win11-64-24h2-gpu-alpha')) {
        $script:registry = @{}; $script:forwarded = $false; $script:reboot = $false
        $blocked = $false
        try { Complete-AzurePuppetRun $code $pool 'registry' 'log' 'fail' 'lock' } catch { $blocked = $true }
        $success = $code -in @(0, 2)
        $gpu = $pool -like '*gpu*'
        if ($registry.last_run_exit -ne $code -or $registry.ContainsKey('inmutable') -ne $success -or
            $forwarded -ne (-not $success) -or $blocked -ne ((-not $success) -or $gpu) -or
            $reboot -ne ((-not $success) -or $gpu)) { throw "Bad result handling: $code / $pool" }
    }
}
$script:controllers = @()
Assert-AzureGpuReady 'win11-64-24h2-alpha'
foreach ($case in @('missing', 'basic', 'broken', 'healthy')) {
    $script:controllers = @()
    if ($case -ne 'missing') {
        $script:controllers = @([pscustomobject]@{
            Name = $case; PNPDeviceID = 'PCI\VEN_10DE&DEV_1234'; DriverVersion = 'test'
            ConfigManagerErrorCode = $(if ($case -eq 'broken') { 43 } else { 0 })
            InstalledDisplayDrivers = $(if ($case -eq 'basic') { 'BasicDisplay.sys' } else { 'nvgridumx.dll' })
        })
    }
    $blocked = $false
    try { Assert-AzureGpuReady 'win11-64-24h2-gpu-alpha' } catch { $blocked = $true }
    if ($blocked -ne ($case -ne 'healthy')) { throw "Bad GPU readiness decision: $case" }
}
'Azure startup checks passed'
