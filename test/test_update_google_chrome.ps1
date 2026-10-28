# Offline behavioral checks; no network, Chrome installation, or real registry writes.
# Run with Windows PowerShell 5.1 or PowerShell 7 from the repository root.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$source = Join-Path $repo 'modules/win_packages/files/Update-GoogleChrome.ps1'
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw $parseErrors[0] }
$logger = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Write-Log' }, $true)
# Keep production control flow and helpers; replace Windows Event Log output and script exit.
$scriptText = (Get-Content $source -Raw).Replace($logger.Extent.Text, 'function Write-Log { param($message, $severity) $state.messages += $message }')
$scriptText = $scriptText -replace '\bexit ([01])\b', 'throw "CHROME_TEST_EXIT:$1"'
$updater = [scriptblock]::Create($scriptText)
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('chrome-update-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $scratch | Out-Null
$oldTemp = $env:TEMP; $oldDrive = $env:SystemDrive
$env:TEMP = $scratch; $env:SystemDrive = $scratch

function Reset-Case {
    $script:state = @{
        installed = '154.0.0.0'; last = '"old"|100'; head = '"new"'; downloaded = '"new"'
        headFails = $false; failures = 0; getCount = 0; headCount = 0; installs = 0
        installerExit = 0; afterInstall = '155.0.0.0'; sleeps = @(); messages = @()
    }
}
function Get-ChildItem {
    param ($Path, $ErrorAction)
    if ($state.installed) {
        $key = [pscustomobject]@{ PSPath = 'HKLM:\test-chrome' }
        $key | Add-Member -MemberType ScriptMethod -Name GetValue -Value { param($Name) $state.installed }
        return $key
    }
}
function Get-ItemProperty {
    param ($Path, $Name, $ErrorAction)
    if ($Name -eq 'chrome_msi_fingerprint') { return [pscustomobject]@{ chrome_msi_fingerprint = $state.last } }
    return [pscustomobject]@{ name = 'Google Chrome' }
}
function Set-ItemProperty {
    param ($Path, $Name, $Value)
    if ($Path -ne 'HKLM:\SOFTWARE\Mozilla\ronin_puppet' -or $Name -ne 'chrome_msi_fingerprint') {
        throw 'Unexpected registry write'
    }
    $state.last = $Value
}
function Test-Path {
    param ($Path)
    if ($Path -like 'HKLM:*') { return $true }
    return Microsoft.PowerShell.Management\Test-Path $Path
}
function Invoke-WebRequest {
    param ($Uri, $Method, $OutFile, $TimeoutSec, [switch] $UseBasicParsing, [switch] $PassThru)
    if ($Uri -ne 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi') {
        throw "Unexpected upstream: $Uri"
    }
    if ($Method -eq 'Head') {
        $state.headCount++
        if ($state.headFails) { throw 'Google HEAD unavailable' }
        return @{ Headers = @{ ETag = $state.head; 'Content-Length' = '100'; 'Last-Modified' = [guid]::NewGuid().ToString() } }
    }
    if (-not $PassThru) { throw 'Download response metadata was discarded' }
    $state.getCount++
    [IO.File]::WriteAllText($OutFile, 'fake MSI')
    if ($state.getCount -le $state.failures) { throw 'Google download unavailable' }
    return @{ Headers = @{ ETag = $state.downloaded; 'Content-Length' = '100' } }
}
function Start-Process {
    param ($FilePath, $ArgumentList, [switch] $Wait, [switch] $PassThru)
    if ($FilePath -ne 'msiexec.exe' -or -not ($Wait -and $PassThru) -or
        $ArgumentList -notcontains '/qn' -or $ArgumentList -notcontains '/norestart') {
        throw 'Incorrect installer invocation'
    }
    $state.installs++
    if ($state.installerExit -in 0, 3010) { $state.installed = $state.afterInstall }
    return @{ ExitCode = $state.installerExit }
}
function Start-Sleep { param($Seconds) $state.sleeps += $Seconds }
function Invoke-Case {
    param ([int] $Expected, [switch] $CheckOnly)
    $actual = $null
    try { & $updater -CheckOnly:$CheckOnly } catch {
        if ($_.Exception.Message -notmatch '^CHROME_TEST_EXIT:([01])$') { throw }
        $actual = [int]$Matches[1]
    }
    if ($actual -ne $Expected) { throw "Expected exit $Expected, got $actual" }
    if (Microsoft.PowerShell.Management\Test-Path (Join-Path $scratch 'googlechromestandaloneenterprise64.msi')) {
        throw 'MSI was not cleaned up'
    }
}
try {
    Reset-Case
    $state.last = '"new"|100'
    Invoke-Case 0
    Invoke-Case 0 -CheckOnly
    if ($state.getCount -or $state.installs) { throw 'Current Chrome reinstalled due to CDN Last-Modified changes' }

    Reset-Case
    Invoke-Case 1 -CheckOnly
    if ($state.getCount -or $state.installs) { throw 'CheckOnly modified the machine' }

    Reset-Case
    $state.installed = $null
    Invoke-Case 0
    if ($state.installs -ne 1 -or $state.last -ne '"new"|100') { throw 'Initial direct installation failed' }

    Reset-Case
    $state.failures = 1
    Invoke-Case 0
    if ($state.getCount -ne 2 -or ($state.sleeps -join ',') -ne '30') { throw 'Transient download retry failed' }

    foreach ($installed in @('154.0.0.0', $null)) {
        Reset-Case
        $state.installed = $installed; $state.failures = 99
        $expected = if ($installed) { 0 } else { 1 }
        Invoke-Case $expected
        if ($state.getCount -ne 3 -or ($state.sleeps -join ',') -ne '30,60' -or $state.installs -or $state.last -ne '"old"|100') {
            throw 'Failed download exceeded retry bound, installed partial content, or marked itself current'
        }

        Reset-Case
        $state.installed = $installed; $state.installerExit = 1603
        Invoke-Case $expected
        if ($state.installs -ne 3 -or $state.last -ne '"old"|100') { throw 'Installer failure was accepted' }
    }

    Reset-Case
    $state.headFails = $true
    Invoke-Case 0
    Invoke-Case 0 -CheckOnly
    if ($state.getCount) { throw 'Working Chrome was changed during HEAD outage' }

    Reset-Case
    $state.installed = $null; $state.headFails = $true
    Invoke-Case 0
    if ($state.last -ne '"new"|100') { throw 'Successful GET after failed HEAD did not record its fingerprint' }

    Reset-Case
    $state.installed = $null; $state.afterInstall = $null
    Invoke-Case 1
    if ($state.last -ne '"old"|100') { throw 'Installer exit 0 without Chrome present was accepted' }

    Reset-Case
    $state.downloaded = $null
    Invoke-Case 0
    if ($state.last -ne '"old"|100') { throw 'Missing GET fingerprint was replaced with the earlier HEAD' }

    Reset-Case
    $state.downloaded = '"newer"'; $state.installerExit = 3010
    Invoke-Case 0
    if ($state.last -ne '"newer"|100') { throw 'Recorded pre-download HEAD instead of installed GET fingerprint' }

    Reset-Case
    $state.head = $null; $state.last = '|100'
    Invoke-Case 0
    if ($state.getCount) { throw 'Content length alone was accepted as a release fingerprint' }

    # Both production callers must use the shared updater with no Chrome Chocolatey path.
    $manifest = Get-Content (Join-Path $repo 'modules/win_packages/manifests/chrome.pp') -Raw
    $maintenance = Get-Content (Join-Path $repo 'modules/win_scheduled_tasks/files/maintainsystem-hw.ps1') -Raw
    if ($manifest -match "provider\s*=>\s*'chocolatey'" -or $maintenance -match 'choco (list|outdated|upgrade)|Get-LatestGoogleChrome') {
        throw 'A Chrome caller still depends on Chocolatey'
    }
    if ($manifest -notmatch 'Update-GoogleChrome.ps1' -or $maintenance -notmatch 'Update-GoogleChrome.ps1') {
        throw 'A caller bypasses the shared updater'
    }
    $maintenanceAst = [Management.Automation.Language.Parser]::ParseInput($maintenance, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw $parseErrors[0] }
    $refresh = $maintenanceAst.Find({ param($node)
        $node -is [Management.Automation.Language.IfStatementAst] -and
        $node.Extent.Text.StartsWith('if (Test-Path $chrome_script)')
    }, $true)
    if (-not $refresh) { throw 'Boot-time Chrome refresh block not found' }
    & {
        function Write-Log { param($message, $severity) $state.messages += $message }
        $chrome_script = Join-Path $scratch 'failing-updater.ps1'
        Set-Content $chrome_script "throw 'fixture updater failure'"
        & ([scriptblock]::Create($refresh.Extent.Text))
        if (-not ($state.messages -match 'fixture updater failure')) { throw 'Unexpected refresh exception was not logged' }
        Set-Content $chrome_script 'exit 1'
        & ([scriptblock]::Create($refresh.Extent.Text))
        Remove-Item $chrome_script
        & ([scriptblock]::Create($refresh.Extent.Text))
        if (-not ($state.messages -match 'not found')) { throw 'Missing updater was not logged' }
    }
    Write-Host 'Direct Chrome installation, caching, CDN changes, retries, outage behavior, exit codes, and caller checks passed.'
} finally {
    $env:TEMP = $oldTemp; $env:SystemDrive = $oldDrive
    Remove-Item -LiteralPath $scratch -Recurse -Force
}
