# Run with pwsh -File test/unit/generic-worker-source-build.ps1.
$ErrorActionPreference = 'Stop'
$script = (Resolve-Path "$PSScriptRoot/../../modules/win_taskcluster/files/build-generic-worker.ps1").Path
$shell = (Get-Process -Id $PID).Path
$root = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $root | Out-Null
try {
    $binary = Join-Path $root 'generic-worker.exe'
    $receiptPath = "$binary.source-build.json"
    Set-Content -LiteralPath $binary -Value 'existing released worker'
    $originalHash = (Get-FileHash -LiteralPath $binary).Hash
    $parameters = @('-Repository', 'taskcluster/taskcluster', '-Revision', ('a' * 40),
        '-GoVersion', '1.27.1', '-Architecture', 'amd64', '-Destination', $binary)
    $receipt = @{
        repository = 'taskcluster/taskcluster'
        revision = 'a' * 40
        go_version = '1.27.1'
        architecture = 'amd64'
        script_hash = (Get-FileHash -LiteralPath $script).Hash
        binary_hash = $originalHash
    }
    function Assert-Check([int]$Expected) {
        & $shell -NoProfile -File $script @parameters -Check
        if ($LASTEXITCODE -ne $Expected) { throw "Expected guard exit $Expected, got $LASTEXITCODE" }
    }
    Assert-Check 1 # An existing release must not suppress the first source build.
    $receipt | ConvertTo-Json | Set-Content -LiteralPath $receiptPath
    Assert-Check 0
    foreach ($field in @('repository', 'revision', 'go_version', 'architecture', 'script_hash', 'binary_hash')) {
        $changed = $receipt.Clone()
        $changed[$field] = 'changed'
        $changed | ConvertTo-Json | Set-Content -LiteralPath $receiptPath
        Assert-Check 1
    }
    Set-Content -LiteralPath $receiptPath -Value 'invalid JSON'
    Assert-Check 1
    $receipt | ConvertTo-Json | Set-Content -LiteralPath $receiptPath
    Set-Content -LiteralPath $binary -Value 'replaced binary'
    Assert-Check 1
    Remove-Item -LiteralPath $binary
    Assert-Check 1

    # A failed download must leave the installed worker and receipt intact.
    Set-Content -LiteralPath $binary -Value 'existing released worker'
    $receiptHash = (Get-FileHash -LiteralPath $receiptPath).Hash
    function Assert-BuildFailure([string]$Expected) {
        try {
            & $script -Repository 'taskcluster/taskcluster' -Revision ('a' * 40) `
                -GoVersion '1.27.1' -Architecture amd64 -Destination $binary
            throw 'Expected build failure'
        } catch {
            if ($_.Exception.Message -ne $Expected) { throw }
        }
        if ((Get-FileHash -LiteralPath $binary).Hash -ne $originalHash -or
            (Get-FileHash -LiteralPath $receiptPath).Hash -ne $receiptHash) {
            throw 'Failed build changed the installed worker or receipt'
        }
    }
    function Invoke-RestMethod { throw 'Injected download failure' }
    Assert-BuildFailure 'Injected download failure'
    function Invoke-RestMethod {
        return @{ version = 'go1.27.1'; files = @(@{
            os = 'windows'; arch = 'amd64'; kind = 'archive'
            filename = 'go.zip'; sha256 = 'invalid'
        }) }
    }
    function Invoke-WebRequest($Uri, $OutFile, [switch]$UseBasicParsing) {
        Set-Content -LiteralPath $OutFile -Value 'invalid archive'
    }
    Assert-BuildFailure 'Go archive checksum mismatch'
    Write-Output 'Source-build guard, download failure, and checksum tests passed.'
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force
}
