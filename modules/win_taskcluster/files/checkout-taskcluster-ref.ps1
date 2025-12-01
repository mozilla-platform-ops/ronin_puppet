# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

param(
    [Parameter(Mandatory=$true)]
    [string]$BuildDir,

    [Parameter(Mandatory=$true)]
    [string]$GitRef
)

# Change to build directory
Set-Location $BuildDir

# Check if we're already on the correct ref
$currentBranch = git rev-parse --abbrev-ref HEAD
if ($currentBranch -eq $GitRef) {
    Write-Host "Already on ref: $GitRef"
    exit 0
}

# Checkout the specified ref
Write-Host "Checking out ref: $GitRef"
git checkout $GitRef

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to checkout ref: $GitRef"
    exit 1
}

Write-Host "Successfully checked out ref: $GitRef"
exit 0
