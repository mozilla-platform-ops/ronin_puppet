<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

RELOPS-2575 :: Keep Google Chrome current without chocolatey.

Chrome used to be installed and upgraded through the PUBLIC chocolatey community
feed, from both puppet (win_packages::chrome) and maintainsystem
(Get-LatestGoogleChrome). A transient feed failure - a per-IP 429, which the whole
MDC1 fleet shares one egress IP for - escalated to Set-PXE in BOTH paths, so a
remote rate limit re-imaged healthy workers and the re-images generated more
requests. Re-imaging cannot fix a remote rate limit: the fresh node makes the
identical request.

We install the SAME artifact the chocolatey package downloaded - Google's
enterprise MSI at a fixed, unversioned URL - so Google-side traffic is unchanged.

WHAT "CURRENT" MEANS HERE, and why it is NOT the version-history API.
  Measured on hw-alpha 2026-09-17: the enterprise MSI installed 153.0.8010.53
  while the API's stable channel reported 154.0.8037.44 (extended reported
  152.0.7977.134, so it is not that either). That URL is the only Chrome we can
  install, so "current" can only mean "the build that URL is serving now".
  Comparing against the API made every boot look stale: the node re-downloaded
  167 MB at deploy AND again on the next boot, six minutes apart, and would have
  done so on every boot of every node forever.

  So: fingerprint the artifact with a HEAD and remember what we last installed.
  The API result is logged for visibility only - it never gates the download.

  The fingerprint is ETag + Content-Length. Last-Modified is deliberately NOT in
  it: two HEADs minutes apart returned 18:58:43 and 19:01:43 GMT for the same
  ETag because it varies per CDN edge, which would force the very re-downloads
  this is here to prevent.

Exit codes are the policy:
  0  Chrome is current, or is stale but working (logged WARN - a stale browser is
     a data-quality wrinkle, not a broken worker)
  1  Chrome is ABSENT and could not be installed (a worker with no Chrome cannot
     run its tasks, so letting puppet fail -> Set-PXE is correct here)
#>
[CmdletBinding()]
param (
    # Report only: exit 0 when Chrome is already current, 1 when work is needed.
    # Used as the `unless` for the puppet exec so the check lives in one place.
    [switch] $CheckOnly,

    [int] $Tries = 3
)

$ErrorActionPreference = 'Stop'
## A progress bar turns the 167 MB download into a crawl under WinPS 5.1.
$ProgressPreference = 'SilentlyContinue'

$msi_url = 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi'
$api_url = 'https://versionhistory.googleapis.com/v1/chrome/platforms/win64/channels/stable/versions?order_by=version%20desc&pageSize=1'
$ronin_key = 'HKLM:\SOFTWARE\Mozilla\ronin_puppet'
$fp_value = 'chrome_msi_fingerprint'

## Same event log + source maintainsystem uses, so nxlog ships it to papertrail
## (the datacenter nxlog config selects Application events from Bootstrap and
## MaintainSystem only; a new source would silently not ship at INFO).
function Write-Log {
    param (
        [string] $message,
        [string] $severity = 'INFO',
        [string] $source = 'MaintainSystem',
        [string] $logName = 'Application'
    )
    if (!([Diagnostics.EventLog]::Exists($logName)) -or !([Diagnostics.EventLog]::SourceExists($source))) {
        New-EventLog -LogName $logName -Source $source
    }
    switch ($severity) {
        'DEBUG' { $entryType = 'SuccessAudit'; $eventId = 2; break }
        'WARN' { $entryType = 'Warning'; $eventId = 3; break }
        'ERROR' { $entryType = 'Error'; $eventId = 4; break }
        default { $entryType = 'Information'; $eventId = 1; break }
    }
    Write-EventLog -LogName $logName -Source $source -EntryType $entryType -Category 0 -EventID $eventId -Message $message
    if ([Environment]::UserInteractive) {
        Write-Host -object $message
    }
}

## NOTE: the Get-* helpers below MUST NOT log. Several ronin PS1 loggers emit with
## Write-Output, which appends the log line to the return value of any function that
## logs and returns - a trap that has already caused one fleet PXE loop. Keep helpers
## log-free and log in the caller. They return $null on failure and never throw: an
## unreachable Google is not a reason to do anything drastic to the node.

function Get-InstalledChromeVersion {
    ## Google Update records the installed product version under Clients\<guid>\pv,
    ## whatever installed it. Same read the chocolatey package's helpers.ps1 used.
    foreach ($root in 'HKLM:\SOFTWARE\Google\Update\Clients', 'HKLM:\SOFTWARE\Wow6432Node\Google\Update\Clients') {
        $key = Get-ChildItem $root -ErrorAction SilentlyContinue |
            Where-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).name -eq 'Google Chrome' } |
            Select-Object -First 1
        if ($key) { return $key.GetValue('pv') }
    }
    return $null
}

function Get-MsiFingerprint {
    ## Identifies the build currently behind the unversioned MSI URL without
    ## downloading 167 MB. ETag + length only - see the header note on Last-Modified.
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $head = Invoke-WebRequest -Uri $msi_url -Method Head -UseBasicParsing -TimeoutSec 30
        $etag = @($head.Headers['ETag'])[0]
        $len = @($head.Headers['Content-Length'])[0]
        if (-not $etag -and -not $len) { return $null }
        return ('{0}|{1}' -f $etag, $len)
    } catch {
        return $null
    }
}

function Get-StableChannelVersion {
    ## Informational only. Never gates the download - see the header note.
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $response = Invoke-RestMethod -Uri $api_url -UseBasicParsing -TimeoutSec 30
        if ($response.versions) { return $response.versions[0].version }
        return $null
    } catch {
        return $null
    }
}

$installed = Get-InstalledChromeVersion
$fingerprint = Get-MsiFingerprint
$last_installed = (Get-ItemProperty -Path $ronin_key -Name $fp_value -ErrorAction SilentlyContinue).$fp_value

## Current = Chrome is present AND it came from the MSI build being served now.
$is_current = ($installed -and $fingerprint -and $fingerprint -eq $last_installed)

if ($CheckOnly) {
    ## An unreachable dl.google.com with Chrome already installed counts as current
    ## so puppet does not fire an install that cannot succeed; boot-time retries later.
    if ($is_current -or ($installed -and -not $fingerprint)) { exit 0 }
    exit 1
}

Write-Log -message ('Update-GoogleChrome :: installed {0} | msi {1} | last installed msi {2} | google stable channel {3}' -f $installed, $fingerprint, $last_installed, (Get-StableChannelVersion)) -severity 'DEBUG'

if ($is_current) {
    Write-Log -message ('Update-GoogleChrome :: Chrome {0} is the build the enterprise MSI is serving; nothing to do' -f $installed) -severity 'DEBUG'
    exit 0
}
if (-not $fingerprint -and $installed) {
    Write-Log -message ('Update-GoogleChrome :: dl.google.com unreachable, leaving Chrome {0} in place' -f $installed) -severity 'WARN'
    exit 0
}

$msi = Join-Path $env:TEMP 'googlechromestandaloneenterprise64.msi'
$log_dir = "$env:systemdrive\logs"
## msiexec returns 1622 if it cannot open its log file, so make sure the dir exists.
if (-not (Test-Path $log_dir)) { New-Item -Path $log_dir -ItemType Directory -Force | Out-Null }
$msi_log = Join-Path $log_dir 'googlechrome-msi.log'

$attempts = 0
$install_ok = $false
for ($i = 1; $i -le $Tries; $i++) {
    $attempts = $i
    try {
        if (Test-Path $msi) { Remove-Item $msi -Force -ErrorAction SilentlyContinue }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $msi_url -OutFile $msi -UseBasicParsing -TimeoutSec 600

        $proc = Start-Process -FilePath 'msiexec.exe' -Wait -PassThru -ArgumentList @(
            '/i', ('"{0}"' -f $msi), '/qn', '/norestart', '/l*v', ('"{0}"' -f $msi_log)
        )
        ## 3010 = success, reboot requested. Chrome does not need one, and nothing
        ## is running yet at this point in maintainsystem, so we do not take it.
        if ($proc.ExitCode -in 0, 3010) { $install_ok = $true; break }
        Write-Log -message ('Update-GoogleChrome :: attempt {0}/{1} msiexec rc={2}' -f $i, $Tries, $proc.ExitCode) -severity 'WARN'
    } catch {
        Write-Log -message ('Update-GoogleChrome :: attempt {0}/{1} failed: {2}' -f $i, $Tries, $_.Exception.Message) -severity 'WARN'
    }
    ## 30s, 60s, 90s - rides out a transient CDN blip without hammering it.
    if ($i -lt $Tries) { Start-Sleep -Seconds (30 * $i) }
}
Remove-Item $msi -Force -ErrorAction SilentlyContinue

$after = Get-InstalledChromeVersion

if ($install_ok -and $after) {
    ## Record WHICH build we installed so later boots skip the download until Google
    ## actually rotates the artifact. Written only after a successful install, so a
    ## failed run retries next boot instead of marking itself done.
    if (-not (Test-Path $ronin_key)) { New-Item -Path $ronin_key -Force | Out-Null }
    Set-ItemProperty -Path $ronin_key -Name $fp_value -Value $fingerprint
    if ($after -eq $installed) {
        Write-Log -message ('Update-GoogleChrome :: Chrome {0} reinstalled from the current MSI ({1} attempt(s))' -f $after, $attempts) -severity 'DEBUG'
    }
    else {
        Write-Log -message ('Update-GoogleChrome :: Chrome {0} -> {1} ({2} attempt(s))' -f $installed, $after, $attempts) -severity 'DEBUG'
    }
    exit 0
}
if ($after) {
    Write-Log -message ('Update-GoogleChrome :: Chrome {0} left in place, install failed after {1} attempt(s) - continuing' -f $after, $attempts) -severity 'WARN'
    exit 0
}

Write-Log -message ('Update-GoogleChrome :: Chrome is NOT installed and could not be installed after {0} attempt(s)' -f $attempts) -severity 'ERROR'
exit 1
