# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

param(
    [Parameter(Mandatory=$true)]
    [string]$RepoUrl,

    [Parameter(Mandatory=$true)]
    [string]$BuildDir
)

# Remove existing build directory if it exists
if (Test-Path $BuildDir) {
    Write-Host "Removing existing build directory: $BuildDir"
    Remove-Item -Path $BuildDir -Recurse -Force
}

# Clone the repository
Write-Host "Cloning repository from $RepoUrl to $BuildDir"
git clone $RepoUrl $BuildDir

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to clone repository"
    exit 1
}

Write-Host "Repository cloned successfully"
exit 0
