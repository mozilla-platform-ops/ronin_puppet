# Run with PowerShell: ./test/fleetbench_cadence.ps1
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '../modules/win_scheduled_tasks/files/maintainsystem-hw.ps1'
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw $errors[0] }
$check = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-FleetbenchCheck' }, $true)
# Replace only the native collector and machine environment writes; exercise real file IO.
Invoke-Expression ($check.Extent.Text.Replace('& $exePath cpu --mode $Mode --duration $Duration --json', 'Invoke-TestCollector').Replace("'Machine'", "'Process'"))
function Write-Log { param($message, $severity) $script:messages += $message }
function Get-ItemProperty {
    param($LiteralPath, $ErrorAction)
    if ($LiteralPath -like '*ronin_puppet') { return $script:deployment }
    return [pscustomobject]@{ version = '0.4.6'; sha256 = $script:sha256 }
}
function New-ItemProperty {
    param($LiteralPath, $Name, $Value, $PropertyType, [switch]$Force, $ErrorAction)
    if ($Name -ne 'fleetbench_deployment_complete') { throw 'Unexpected registry write' }
    $script:deployment.fleetbench_deployment_complete = $Value
}
function Invoke-TestCollector {
    $script:runs++
    $global:LASTEXITCODE = $script:collectorExit
    if (-not $script:emptyOutput) { '{}' }
}
function Move-Item {
    [CmdletBinding()]
    param($LiteralPath, $Destination, [switch]$Force)
    if ($script:failPublish) { throw 'simulated interrupted publish' }
    Microsoft.PowerShell.Management\Move-Item @PSBoundParameters
}
function Get-FleetbenchMetrics { return [pscustomobject]@{ Ok = $false } }
function Write-FleetbenchStatus { }
$script:now = [datetime]::UtcNow
function Get-Date { return $script:now }
function Check-Run($Expected) {
    $script:runs = 0; $script:messages = @()
    Invoke-FleetbenchCheck -InstallDir $dir -ResultsDir $results
    if ($script:runs -ne $Expected) { throw "Expected $Expected runs, got $script:runs : $script:messages" }
}
$dir = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
try {
    $results = Join-Path $dir 'results'
    New-Item -ItemType Directory -Path $results -Force | Out-Null
    $binary = Join-Path $dir 'fleetbench-0.4.6.exe'
    Set-Content -LiteralPath $binary -Value 'pinned collector'
    $script:sha256 = (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash
    $script:deployment = [pscustomobject]@{
        worker_pool_id = 'win11-64-24h2-hw'
        fleetbench_deployment = ''; fleetbench_deployment_complete = ''
    }
    $script:collectorExit = 0; $script:emptyOutput = $false
    Set-Content (Join-Path $results 'fleetbench_status.json') '{}'
    Set-Content (Join-Path $results 'interrupted_cpu.json.partial') '{}'
    Check-Run 1 # no prior result, ignoring status and partial files
    Check-Run 0 # recent result
    $result = Get-ChildItem $results -Filter '*_cpu.json'
    $result.LastWriteTimeUtc = $script:now.AddHours(-72)
    Check-Run 0 # exactly 72 hours is not older than 72 hours
    $result.LastWriteTimeUtc = $script:now.AddHours(-72).AddSeconds(-1)
    Check-Run 1
    Check-Run 0

    $script:deployment.fleetbench_deployment = 'deploy-1'
    Check-Run 1 # override ignores a fresh result
    if ($script:deployment.fleetbench_deployment_complete -ne 'deploy-1') { throw 'Override not consumed' }
    Check-Run 0 # next boot in the same OS
    $script:deployment.fleetbench_deployment = 'deploy-2'
    $script:collectorExit = 1
    Check-Run 1
    if ($script:deployment.fleetbench_deployment_complete -ne 'deploy-1') { throw 'Failed run consumed override' }
    $script:collectorExit = 0; $script:emptyOutput = $true
    Check-Run 1
    if ($script:deployment.fleetbench_deployment_complete -ne 'deploy-1') { throw 'Empty run consumed override' }
    $script:emptyOutput = $false; $script:failPublish = $true
    Check-Run 1
    if ($script:deployment.fleetbench_deployment_complete -ne 'deploy-1') { throw 'Failed publish consumed override' }
    $script:failPublish = $false
    Check-Run 1 # retry succeeds
    Check-Run 0
    (Get-ChildItem $results -Filter '*_cpu.json' | Select-Object -First 1).LastWriteTimeUtc = $script:now.AddHours(-73)
    Check-Run 1 # normal cadence resumes after the forced run
    $script:deployment.fleetbench_deployment = ''
    Check-Run 0 # redeploy without the override reuses persistent results
    foreach ($pool in @('win11-64-24h2-hw-alpha', 'win11-64-24h2-hw-ref-alpha')) {
        $script:deployment.worker_pool_id = $pool
        $script:deployment.fleetbench_deployment = $pool
        Check-Run 1 # alpha and reference alpha honor the deployment override
        if ($script:deployment.fleetbench_deployment_complete -ne $pool) { throw "Override not consumed for $pool" }
        Check-Run 0 # and honor the same cadence afterwards
        (Get-ChildItem $results -Filter '*_cpu.json' | Select-Object -First 1).LastWriteTimeUtc = $script:now.AddHours(-73)
        Check-Run 1 # alpha pools also run when their prior result expires
    }
}
finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
$global:LASTEXITCODE = 0
Write-Host 'Fleetbench cadence and deployment override checks passed.'
