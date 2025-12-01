# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

param(
    [Parameter(Mandatory=$true)]
    [string]$BuildDir,

    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

# Change to build directory
Set-Location $BuildDir

# Get the current git revision
Write-Host "Getting git revision..."
$revision = git rev-parse HEAD

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get git revision"
    exit 1
}

Write-Host "Building generic-worker from revision: $revision"

# Set CGO_ENABLED to 0 for static binary
$env:CGO_ENABLED = "0"

# Build the generic-worker binary
Write-Host "Running go build..."
go build -tags multiuser -o $OutputPath -ldflags "-X main.revision=$revision" .\workers\generic-worker

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build generic-worker"
    exit 1
}

Write-Host "Successfully built generic-worker at: $OutputPath"
exit 0
