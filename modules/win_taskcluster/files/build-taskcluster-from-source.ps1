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

Write-Log -Message "=== Starting Taskcluster build from source ===" -severity INFO
Write-Log -Message ("Build directory: {0}" -f $BuildDir) -severity INFO
Write-Log -Message ("Generic worker directory: {0}" -f $GenericWorkerDir) -severity INFO
Write-Log -Message ("Taskcluster repository: {0}" -f $TaskclusterRepo) -severity INFO
Write-Log -Message ("Taskcluster ref: {0}" -f $TaskclusterRef) -severity INFO

$OutputPath = Join-Path $GenericWorkerDir "generic-worker.exe"
Write-Log -Message ("Output path: {0}" -f $OutputPath) -severity INFO

# Refresh PATH to pick up newly installed tools
Write-Log -Message "Refreshing PATH environment variable..." -severity INFO
$env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
Write-Log -Message ("Updated PATH: {0}" -f $env:PATH) -severity DEBUG

# Step 1: Clone or update repository
if (Test-Path $BuildDir) {
    Write-Log -Message "Build directory already exists, checking if it's a git repository..." -severity INFO

    Push-Location $BuildDir
    try {
        git rev-parse --is-inside-work-tree 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Log -Message "Existing git repository found, fetching latest changes..." -severity INFO
            git fetch origin 2>&1 | ForEach-Object { Write-Log -Message $_ -severity DEBUG }
            if ($LASTEXITCODE -ne 0) {
                Write-Log -Message "Failed to fetch from repository" -severity ERROR
                exit 1
            }
        }
        else {
            Write-Log -Message "Directory exists but is not a git repository, removing it..." -severity WARN
            Pop-Location
            Remove-Item -Path $BuildDir -Recurse -Force
            Write-Log -Message ("Cloning repository from {0}..." -f $TaskclusterRepo) -severity INFO
            git clone $TaskclusterRepo $BuildDir 2>&1 | ForEach-Object { Write-Log -Message $_ -severity DEBUG }
            if ($LASTEXITCODE -ne 0) {
                Write-Log -Message "Failed to clone repository" -severity ERROR
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
    Write-Log -Message ("Cloning repository from {0}..." -f $TaskclusterRepo) -severity INFO
    git clone $TaskclusterRepo $BuildDir
    if ($LASTEXITCODE -ne 0) {
        Write-Log -Message "Failed to clone repository" -severity ERROR
        exit 1
    }
}

# Step 2: Checkout the specified ref
Write-Log -Message "Changing to build directory..." -severity INFO
Push-Location $BuildDir

try {
    Write-Log -Message ("Checking out ref: {0}..." -f $TaskclusterRef) -severity INFO
    git checkout $TaskclusterRef
    if ($LASTEXITCODE -ne 0) {
        Write-Log -Message ("Failed to checkout ref: {0}" -f $TaskclusterRef) -severity ERROR
        exit 1
    }

    # Get the current git revision
    Write-Log -Message "Getting git revision..." -severity INFO
    $revision = git rev-parse HEAD
    if ($LASTEXITCODE -ne 0) {
        Write-Log -Message ("Failed to get git revision. Error: {0}" -f $revision) -severity ERROR
        exit 1
    }
    Write-Log -Message ("Git revision: {0}" -f $revision) -severity INFO

    # Step 3: Check for Go installation
    Write-Log -Message "Checking for Go installation..." -severity INFO
    $goVersion = go version
    if ($LASTEXITCODE -ne 0) {
        Write-Log -Message ("Go is not available in PATH. Error: {0}" -f $goVersion) -severity ERROR
        Write-Log -Message ("Current PATH: {0}" -f $env:PATH) -severity DEBUG
        exit 1
    }
    Write-Log -Message ("Go version: {0}" -f $goVersion) -severity INFO

    # Step 4: Build generic-worker
    Write-Log -Message "Setting CGO_ENABLED=0 for static binary..." -severity INFO
    $env:CGO_ENABLED = "0"

    Write-Log -Message "Running go build..." -severity INFO
    $ldflagsValue = "`"-X main.revision=$revision`""
    $buildArgs = @(
        "build",
        "-tags",
        "multiuser",
        "-o",
        $OutputPath,
        "-ldflags",
        $ldflagsValue,
        ".\workers\generic-worker"
    )
    Write-Log -Message ("Build command: go {0}" -f ($buildArgs -join ' ')) -severity DEBUG

    $buildProcess = Start-Process -FilePath "go" -ArgumentList $buildArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$env:TEMP\go-build-stdout.log" -RedirectStandardError "$env:TEMP\go-build-stderr.log"

    # Log the output
    if (Test-Path "$env:TEMP\go-build-stdout.log") {
        Get-Content "$env:TEMP\go-build-stdout.log" | ForEach-Object { Write-Log -Message $_ -severity DEBUG }
        Remove-Item "$env:TEMP\go-build-stdout.log" -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path "$env:TEMP\go-build-stderr.log") {
        Get-Content "$env:TEMP\go-build-stderr.log" | ForEach-Object { Write-Log -Message $_ -severity DEBUG }
        Remove-Item "$env:TEMP\go-build-stderr.log" -Force -ErrorAction SilentlyContinue
    }

    if ($buildProcess.ExitCode -ne 0) {
        Write-Log -Message ("Failed to build generic-worker. Exit code: {0}" -f $buildProcess.ExitCode) -severity ERROR
        exit 1
    }

    # Verify the output file was created
    if (-not (Test-Path $OutputPath)) {
        Write-Log -Message ("Build appeared to succeed but output file was not created: {0}" -f $OutputPath) -severity ERROR
        exit 1
    }

    Write-Log -Message ("=== Successfully built generic-worker at: {0} ===" -f $OutputPath) -severity INFO
    Write-Log -Message ("Binary size: {0} MB" -f ((Get-Item $OutputPath).Length / 1MB)) -severity INFO
    exit 0

}
finally {
    Pop-Location
}
