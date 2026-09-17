# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

<#
.SYNOPSIS
    Wrapper that runs the fleetbench collector and saves its JSON output to a
    known results location.

.DESCRIPTION
    Invokes the fleetbench collector binary for the given suite/mode, captures
    its JSON envelope from stdout, and writes it atomically (via a .partial
    file + rename) into the results directory using a sortable, host-scoped
    filename: <UTC-timestamp>_<host>_<suite>.json

    Deployed by the win_fleetbench Puppet module (RELOPS-2402). Intended to be
    invoked by a scheduled task / worker-startup hook in a later step.

.PARAMETER BinaryPath
    Full path to the fleetbench collector executable.

.PARAMETER ResultsDir
    Directory where result envelopes are written.

.PARAMETER Suite
    Collector subcommand to run (default: cpu).

.PARAMETER Mode
    Benchmark mode passed to the collector (quick|normal|long; default: normal).

.PARAMETER ExtraArgs
    Additional arguments forwarded verbatim to the collector (e.g. --duration 10m).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BinaryPath,

    [Parameter(Mandatory = $true)]
    [string]$ResultsDir,

    [string]$Suite = 'cpu',

    [string]$Mode = 'normal',

    [string[]]$ExtraArgs = @()
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $BinaryPath)) {
    Write-Error "fleetbench binary not found: $BinaryPath"
    exit 1
}

# Ensure the known results location exists.
if (-not (Test-Path -LiteralPath $ResultsDir)) {
    New-Item -ItemType Directory -Path $ResultsDir -Force | Out-Null
}

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH-mm-ssZ')
$hostName  = $env:COMPUTERNAME
$baseName  = "${timestamp}_${hostName}_${Suite}"
$finalPath = Join-Path $ResultsDir "$baseName.json"
$partPath  = "$finalPath.partial"
$errPath   = Join-Path $ResultsDir "$baseName.stderr.log"

$collectorArgs = @($Suite, '--mode', $Mode, '--json') + $ExtraArgs

Write-Host "Running: $BinaryPath $($collectorArgs -join ' ')"

# Run the collector, capturing stdout to the .partial file and stderr to a log.
& $BinaryPath @collectorArgs 1> $partPath 2> $errPath
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0 -and (Test-Path -LiteralPath $partPath) -and (Get-Item -LiteralPath $partPath).Length -gt 0) {
    Move-Item -LiteralPath $partPath -Destination $finalPath -Force
    # No stderr content worth keeping on success.
    if ((Test-Path -LiteralPath $errPath) -and (Get-Item -LiteralPath $errPath).Length -eq 0) {
        Remove-Item -LiteralPath $errPath -Force
    }
    Write-Host "fleetbench result written: $finalPath"
    exit 0
}
else {
    # Preserve the partial output for diagnostics on failure.
    if (Test-Path -LiteralPath $partPath) {
        Move-Item -LiteralPath $partPath -Destination "$finalPath.failed" -Force
    }
    Write-Error "fleetbench collector failed (exit $exitCode); see $errPath"
    exit $exitCode
}
