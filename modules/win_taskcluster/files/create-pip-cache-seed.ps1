# Test branch only: prepare a real pip download cache.
$ErrorActionPreference = 'Stop'
$seed = 'C:\cache-seeds\pip'
$download = 'C:\cache-seeds\pip-download'
& C:\mozilla-build\python3\python3.exe -m pip --isolated --disable-pip-version-check --cache-dir $seed download --index-url https://pypi.org/simple --only-binary=:all: --no-deps --dest $download six==1.17.0
if ($LASTEXITCODE -ne 0) { throw "Preparing pip cache failed: $LASTEXITCODE" }
if (-not (Get-ChildItem $seed -Recurse -File)) { throw 'pip did not cache the download' }
@{ package = 'six==1.17.0'; worker_revision = 'e29a4639fd4402431b7a01cb9982b145c3077aa9' } | ConvertTo-Json | Set-Content "$seed\preloaded-cache-proof.json" -Encoding ASCII
Remove-Item $download -Recurse -Force
Set-Content "$seed.created" 'six==1.17.0' -Encoding ASCII
