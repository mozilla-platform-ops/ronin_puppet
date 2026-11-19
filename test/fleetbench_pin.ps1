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
function Get-ItemProperty {
    param($LiteralPath, $ErrorAction)
    if ($LiteralPath -eq 'HKLM:\SOFTWARE\Mozilla\ronin_puppet') {
        return [pscustomobject]@{ worker_pool_id = $script:pool }
    }
    $script:pinReads++
    return [pscustomobject]@{ version = '0.4.6'; sha256 = $script:sha256 }
}

$dir = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
try {
    $results = Join-Path $dir 'results'
    New-Item -ItemType Directory -Path $results -Force | Out-Null
    $binary = Join-Path $dir 'fleetbench-0.4.6.exe'
    Set-Content -LiteralPath $binary -Value 'known collector'
    Set-Content -LiteralPath (Join-Path $dir 'fleetbench-999.exe') -Value 'newer untrusted collector'
    Set-Content -LiteralPath (Join-Path $results 'recent_cpu.json') -Value '{}'
    $script:sha256 = (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash

    $script:pool = 'win11-64-24h2-hw'
    $script:messages = @()
    Invoke-FleetbenchCheck -InstallDir $dir -ResultsDir $results
    if (-not ($script:messages -match 'last benchmark')) { throw 'Pinned collector did not reach cadence gate' }

    foreach ($pool in @('win11-64-24h2-hw-alpha', 'win11-64-24h2-hw-ref-alpha', 'releng-hardware/win11-64-24h2-hw-alpha', 'win11-64-24h2-hw', 'win11-64-24h2-hw-ref', 'win11-64-24h2-hw-perf-debug')) {
        $script:pool = $pool
        $script:messages = @()
        Invoke-FleetbenchCheck -InstallDir $dir -ResultsDir $results
        if (-not ($script:messages -match 'last benchmark')) { throw "Benchmark was disabled: $pool" }
    }

    Set-Content -LiteralPath $binary -Value 'tampered collector'
    $script:messages = @()
    Invoke-FleetbenchCheck -InstallDir $dir -ResultsDir $results
    if (-not ($script:messages -match 'failed SHA-256 verification')) { throw 'Tampered pinned collector was accepted' }
}
finally {
    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
}

# All pools report UNKNOWN when no benchmark status exists.
foreach ($name in @('check_fleetbench.ps1', 'check_fleetbench_variance.ps1')) {
    $path = Join-Path $PSScriptRoot "../modules/win_nsclient/files/$name"
    $body = [IO.File]::ReadAllText($path)
    $body = $body.Replace('exit $code', 'throw "CHECK_EXIT:$code"')
    function Test-Path { return $false }
    foreach ($pool in @('win11-64-24h2-hw-alpha', 'win11-64-24h2-hw-ref-alpha', 'win11-64-24h2-hw')) {
        $script:pool = $pool
        $output = ''
        try { $output = (& ([scriptblock]::Create($body)) | Out-String) }
        catch {
            $expected = 'CHECK_EXIT:3'
            if ($_.Exception.Message -ne $expected) { throw }
            continue
        }
        throw "Status check did not exit: $name / $pool / $output"
    }
}
Write-Host 'Fleetbench pin and pool policy checks passed.'
