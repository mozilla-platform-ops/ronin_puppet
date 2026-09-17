# Test branch only: full Gecko checkout for Taskcluster PR #9162.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$seed = 'C:\cache-seeds\gecko'
$revision = '98bdb8213106035b828fa7f3862cc626b8907579'
$hg = 'C:\Program Files\Mercurial\hg.exe'
$extension = 'C:\cache-seeds\robustcheckout.py'
Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/mozilla-firefox/firefox/d3e7209270e80f1afaf7945fe2cab47018fe0f6f/testing/mozharness/external_tools/robustcheckout.py' -OutFile $extension
& $hg --config "extensions.robustcheckout=$extension" robustcheckout --sharebase C:\hg-shared --revision $revision --purge https://hg.mozilla.org/integration/autoland "$seed\src"
if ($LASTEXITCODE -ne 0) { throw "Gecko seed checkout failed: $LASTEXITCODE" }
$actual = & $hg -R "$seed\src" log -r . -T '{node}'
if ($LASTEXITCODE -ne 0 -or $actual -ne $revision) { throw 'Gecko seed revision mismatch' }
if (Test-Path "$seed\src\.hg\sparse") { throw 'Gecko seed must be a full checkout' }
@{ revision = $revision; worker_revision = 'd94e81f4f2f0061be41c753c5f3e4cce2c3dcb95'; shared_store = 'C:\hg-shared' } | ConvertTo-Json | Set-Content "$seed\seed-receipt.json" -Encoding ASCII
Set-Content "$seed\src\.hg\preloaded-cache-proof" -Value $revision -Encoding ASCII
Set-Content "$seed.created" -Value $revision -Encoding ASCII
