# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

param(
    [Parameter(Mandatory = $true)]
    [string]$BuildDir,

    [Parameter(Mandatory = $true)]
    [string]$GenericWorkerDir,

    [Parameter(Mandatory = $false)]
    [string]$TaskclusterRepo = "https://github.com/taskcluster/taskcluster",

    [Parameter(Mandatory = $false)]
    [string]$TaskclusterRef = "main"
)

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

Write-Log -message "=== Starting Taskcluster build from source ===" -severity INFO
Write-Log -message "Build directory: $BuildDir" -severity INFO
Write-Log -message "Generic worker directory: $GenericWorkerDir" -severity INFO
Write-Log -message "Taskcluster repository: $TaskclusterRepo" -severity INFO
Write-Log -message "Taskcluster ref: $TaskclusterRef" -severity INFO

$OutputPath = Join-Path $GenericWorkerDir "generic-worker.exe"
Write-Log -message "Output path: $OutputPath" -severity INFO

# Refresh PATH to pick up newly installed tools
Write-Log -message "Refreshing PATH environment variable..." -severity INFO
$env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
Write-Log -message "Updated PATH: $env:PATH" -severity DEBUG

# Step 1: Clone or update repository
if (Test-Path $BuildDir) {
    Write-Log -message "Build directory already exists, checking if it's a git repository..." -severity INFO
    
    Push-Location $BuildDir
    try {
        $isGitRepo = git rev-parse --is-inside-work-tree 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log -message "Existing git repository found, fetching latest changes..." -severity INFO
            git fetch origin 2>&1 | ForEach-Object { Write-Log -message $_ -severity DEBUG }
            if ($LASTEXITCODE -ne 0) {
                Write-Log -message "Failed to fetch from repository" -severity ERROR
                exit 1
            }
        }
        else {
            Write-Log -message "Directory exists but is not a git repository, removing it..." -severity WARN
            Pop-Location
            Remove-Item -Path $BuildDir -Recurse -Force
            Write-Log -message "Cloning repository from $TaskclusterRepo..." -severity INFO
            git clone $TaskclusterRepo $BuildDir 2>&1 | ForEach-Object { Write-Log -message $_ -severity DEBUG }
            if ($LASTEXITCODE -ne 0) {
                Write-Log -message "Failed to clone repository" -severity ERROR
                exit 1
            }
            Push-Location $BuildDir
        }
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Log -message "Cloning repository from $TaskclusterRepo..." -severity INFO
    git clone $TaskclusterRepo $BuildDir 2>&1 | ForEach-Object { Write-Log -message $_ -severity DEBUG }
    if ($LASTEXITCODE -ne 0) {
        Write-Log -message "Failed to clone repository" -severity ERROR
        exit 1
    }
}

# Step 2: Checkout the specified ref
Write-Log -message "Changing to build directory..." -severity INFO
Push-Location $BuildDir

try {
    Write-Log -message "Checking out ref: $TaskclusterRef..." -severity INFO
    git checkout $TaskclusterRef 2>&1 | ForEach-Object { Write-Log -message $_ -severity DEBUG }
    if ($LASTEXITCODE -ne 0) {
        Write-Log -message "Failed to checkout ref: $TaskclusterRef" -severity ERROR
        exit 1
    }

    # Get the current git revision
    Write-Log -message "Getting git revision..." -severity INFO
    $revision = git rev-parse HEAD 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log -message "Failed to get git revision. Error: $revision" -severity ERROR
        exit 1
    }
    Write-Log -message "Git revision: $revision" -severity INFO

    # Step 3: Check for Go installation
    Write-Log -message "Checking for Go installation..." -severity INFO
    $goVersion = go version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log -message "Go is not available in PATH. Error: $goVersion" -severity ERROR
        Write-Log -message "Current PATH: $env:PATH" -severity DEBUG
        exit 1
    }
    Write-Log -message "Go version: $goVersion" -severity INFO

    # Step 4: Build generic-worker
    Write-Log -message "Setting CGO_ENABLED=0 for static binary..." -severity INFO
    $env:CGO_ENABLED = "0"

    Write-Log -message "Running go build..." -severity INFO
    $buildCommand = "go build -tags multiuser -o `"$OutputPath`" -ldflags `"-X main.revision=$revision`" .\workers\generic-worker"
    Write-Log -message "Build command: $buildCommand" -severity DEBUG
    
    go build -tags multiuser -o $OutputPath -ldflags "-X main.revision=$revision" .\workers\generic-worker 2>&1 | ForEach-Object { Write-Log -message $_ -severity DEBUG }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log -message "Failed to build generic-worker" -severity ERROR
        exit 1
    }

    # Verify the output file was created
    if (-not (Test-Path $OutputPath)) {
        Write-Log -message "Build appeared to succeed but output file was not created: $OutputPath" -severity ERROR
        exit 1
    }

    Write-Log -message "=== Successfully built generic-worker at: $OutputPath ===" -severity INFO
    Write-Log -message "Binary size: $((Get-Item $OutputPath).Length / 1MB) MB" -severity INFO
    exit 0

}
finally {
    Pop-Location
}
