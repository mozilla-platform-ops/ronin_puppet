# Test branch only: marker seed for Taskcluster PR #9162.
$ErrorActionPreference = 'Stop'
$seed = 'C:\cache-seeds\relops-8809-smoke-20260918'
New-Item -Path $seed -ItemType Directory -Force | Out-Null
Set-Content -LiteralPath "$seed\marker.txt" -Value 'from-image-e29a4639f' -Encoding ASCII
# Write this last. It stays outside the seed after generic-worker consumes it.
Set-Content -LiteralPath "$seed.created" -Value 'e29a4639fd4402431b7a01cb9982b145c3077aa9' -Encoding ASCII
