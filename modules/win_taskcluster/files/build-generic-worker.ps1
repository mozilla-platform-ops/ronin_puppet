# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')][string]$Repository,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$Revision,
    [Parameter(Mandatory)][ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+$')][string]$GoVersion,
    [Parameter(Mandatory)][ValidateSet('amd64', 'arm64')][string]$Architecture,
    [Parameter(Mandatory)][string]$Destination,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$receiptPath = "$Destination.source-build.json"
$scriptHash = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
if ($Check) {
    try {
        $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
        if ($receipt.repository -eq $Repository -and $receipt.revision -eq $Revision -and
            $receipt.go_version -eq $GoVersion -and $receipt.architecture -eq $Architecture -and
            $receipt.script_hash -eq $scriptHash -and
            $receipt.binary_hash -eq (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash) {
            exit 0
        }
    } catch {
        # Missing or invalid state requires a build.
    }
    exit 1
}

# Use a private toolchain. Do not change the Go installation used by tasks.
$buildDir = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $buildDir | Out-Null
try {
    $ProgressPreference = 'SilentlyContinue'
    $releases = Invoke-RestMethod -Uri 'https://go.dev/dl/?mode=json&include=all'
    $release = $releases | Where-Object { $_.version -eq "go$GoVersion" }
    $archive = @($release.files | Where-Object {
        $_.os -eq 'windows' -and $_.arch -eq $Architecture -and $_.kind -eq 'archive'
    })
    if ($archive.Count -ne 1) { throw "No unique Go $GoVersion archive for Windows $Architecture" }
    $goZip = Join-Path $buildDir 'go.zip'
    Invoke-WebRequest -UseBasicParsing -Uri "https://go.dev/dl/$($archive[0].filename)" -OutFile $goZip
    if ((Get-FileHash -LiteralPath $goZip -Algorithm SHA256).Hash -ne $archive[0].sha256) {
        throw 'Go archive checksum mismatch'
    }
    Expand-Archive -LiteralPath $goZip -DestinationPath $buildDir
    $sourceZip = Join-Path $buildDir 'source.zip'
    Invoke-WebRequest -UseBasicParsing -Uri "https://codeload.github.com/$Repository/zip/$Revision" -OutFile $sourceZip
    $sourceDir = Join-Path $buildDir 'source'
    Expand-Archive -LiteralPath $sourceZip -DestinationPath $sourceDir
    $checkout = @(Get-ChildItem -LiteralPath $sourceDir -Directory)
    if ($checkout.Count -ne 1) { throw 'Expected one source directory' }
    $go = Join-Path $buildDir 'go\bin\go.exe'
    $env:GOROOT = Join-Path $buildDir 'go'
    $env:GOTOOLCHAIN = 'local'
    $env:GOOS = 'windows'
    $env:GOARCH = $Architecture
    $env:CGO_ENABLED = '0'
    $binary = Join-Path $buildDir 'generic-worker.exe'
    & $go -C $checkout[0].FullName build -tags multiuser -buildvcs=false -o $binary ./workers/generic-worker
    if ($LASTEXITCODE -ne 0) { throw "go build failed: $LASTEXITCODE" }
    # Keep the installed worker until the build succeeds. A locked file fails the Puppet run.
    Copy-Item -LiteralPath $binary -Destination $Destination -Force
    @{
        repository = $Repository
        revision = $Revision
        go_version = $GoVersion
        architecture = $Architecture
        script_hash = $scriptHash
        binary_hash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    } | ConvertTo-Json | Set-Content -LiteralPath $receiptPath -Encoding ASCII
    Write-Output "Installed generic-worker from $Repository at $Revision ($Architecture)"
} finally {
    Remove-Item -LiteralPath $buildDir -Recurse -Force
}
