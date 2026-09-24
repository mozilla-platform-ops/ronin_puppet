# Run locally on Windows: powershell.exe -NoProfile -File test/fleetbench_pin.ps1
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '..\modules\win_scheduled_tasks\files\maintainsystem-hw.ps1'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw $errors[0] }
$check = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-FleetbenchCheck' }, $true)
if (-not $check) { throw 'Invoke-FleetbenchCheck not found' }
Invoke-Expression $check.Extent.Text

function Write-Log { param($message, $severity) $script:messages += $message }
function Get-ItemProperty { param($LiteralPath, $ErrorAction) [pscustomobject]@{ version = '0.4.6'; sha256 = $script:sha256 } }

$dir = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
try {
    $results = Join-Path $dir 'results'
    New-Item -ItemType Directory -Path $results -Force | Out-Null
    $binary = Join-Path $dir 'fleetbench-0.4.6.exe'
    Set-Content -LiteralPath $binary -Value 'known collector'
    Set-Content -LiteralPath (Join-Path $dir 'fleetbench-999.exe') -Value 'newer untrusted collector'
    Set-Content -LiteralPath (Join-Path $results 'recent_cpu.json') -Value '{}'
    $script:sha256 = (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash

    $script:messages = @()
    Invoke-FleetbenchCheck -InstallDir $dir -ResultsDir $results
    if (-not ($script:messages -match 'last benchmark')) { throw 'Pinned collector did not reach cadence gate' }

    Set-Content -LiteralPath $binary -Value 'tampered collector'
    $script:messages = @()
    Invoke-FleetbenchCheck -InstallDir $dir -ResultsDir $results
    if (-not ($script:messages -match 'failed SHA-256 verification')) { throw 'Tampered pinned collector was accepted' }
}
finally {
    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
}
