# Test branch only: marker seed for Taskcluster PR #9162.
$ErrorActionPreference = 'Stop'
$seed = 'C:\cache-seeds\relops-8809-smoke-20260917'
New-Item -Path $seed -ItemType Directory -Force | Out-Null
Set-Content -LiteralPath "$seed\marker.txt" -Value 'from-image-78da8f580' -Encoding ASCII
# Write this last. It stays outside the seed after generic-worker consumes it.
Set-Content -LiteralPath "$seed.created" -Value '78da8f5807fb6f033039394ad9c196ed81bc8de2' -Encoding ASCII
