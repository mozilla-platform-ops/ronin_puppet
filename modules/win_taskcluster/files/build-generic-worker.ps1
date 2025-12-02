# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

function Write-Log {
    param (
        [string] $message,
        [string] $severity = 'INFO',
        [string] $source = 'BootStrap',
        [string] $logName = 'Application'
    )
    if (!([Diagnostics.EventLog]::Exists($logName)) -or !([Diagnostics.EventLog]::SourceExists($source))) {
        New-EventLog -LogName $logName -Source $source
    }
    switch ($severity) {
        'DEBUG' {
            $entryType = 'SuccessAudit'
            $eventId = 2
            break
        }
        'WARN' {
            $entryType = 'Warning'
            $eventId = 3
            break
        }
        'ERROR' {
            $entryType = 'Error'
            $eventId = 4
            break
        }
        default {
            $entryType = 'Information'
            $eventId = 1
            break
        }
    }
    Write-EventLog -LogName $logName -Source $source -EntryType $entryType -Category 0 -EventID $eventId -Message $message
    if ([Environment]::UserInteractive) {
        $fc = @{ 'Information' = 'White'; 'Error' = 'Red'; 'Warning' = 'DarkYellow'; 'SuccessAudit' = 'DarkGray' }[$entryType]
        Write-Host  -object $message -ForegroundColor $fc
    }
}

param(
    [Parameter(Mandatory=$true)]
    [string]$BuildDir,

    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

Write-Log -message "=== Starting generic-worker build ===" -severity INFO
Write-Log -message "Build directory: $BuildDir" -severity INFO
Write-Log -message "Output path: $OutputPath" -severity INFO

# Check if build directory exists
if (-not (Test-Path $BuildDir)) {
    Write-Log -message "Build directory does not exist: $BuildDir" -severity ERROR
    exit 1
}

# Change to build directory
Write-Log -message "Changing to build directory..." -severity INFO
Set-Location $BuildDir

# Get the current git revision
Write-Log -message "Getting git revision..." -severity INFO
$revision = git rev-parse HEAD 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Log -message "Failed to get git revision. Error: $revision" -severity ERROR
    exit 1
}

Write-Log -message "Git revision: $revision" -severity INFO

# Check if Go is available
Write-Log -message "Checking for Go installation..." -severity INFO
$goVersion = go version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Log -message "Go is not available in PATH. Error: $goVersion" -severity ERROR
    Write-Log -message "Current PATH: $env:PATH" -severity DEBUG
    exit 1
}
Write-Log -message "Go version: $goVersion" -severity INFO

# Set CGO_ENABLED to 0 for static binary
$env:CGO_ENABLED = "0"
Write-Log -message "Set CGO_ENABLED=0" -severity INFO

# Build the generic-worker binary
Write-Log -message "Running go build..." -severity INFO
Write-Log -message "Command: go build -tags multiuser -o $OutputPath -ldflags `"-X main.revision=$revision`" .\workers\generic-worker" -severity DEBUG
go build -tags multiuser -o $OutputPath -ldflags "-X main.revision=$revision" .\workers\generic-worker 2>&1 | Tee-Object -Variable buildOutput

if ($LASTEXITCODE -ne 0) {
    Write-Log -message "Failed to build generic-worker. Build output: $buildOutput" -severity ERROR
    exit 1
}

# Verify the output file was created
if (-not (Test-Path $OutputPath)) {
    Write-Log -message "Build appeared to succeed but output file was not created: $OutputPath" -severity ERROR
    exit 1
}

Write-Log -message "=== Successfully built generic-worker at: $OutputPath ===" -severity INFO
exit 0
