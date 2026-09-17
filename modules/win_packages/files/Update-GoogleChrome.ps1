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

This asks the question we actually care about - "is the installed Chrome the
current stable Chrome" - against first-party Google endpoints only:

  installed  HKLM:\SOFTWARE\Google\Update\Clients\* -> pv
  current    versionhistory.googleapis.com (public, no auth)
  payload    dl.google.com enterprise MSI - the SAME url and file the chocolatey
             package downloaded anyway, so Google-side traffic is unchanged.

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
## log-free and log in the caller.

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

function Get-CurrentChromeVersion {
    ## $null (never a throw) on any failure - an unreachable Google is not a
    ## reason to do anything drastic to the node.
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $response = Invoke-RestMethod -Uri $api_url -UseBasicParsing -TimeoutSec 30
        if ($response.versions -and $response.versions[0].version) { return $response.versions[0].version }
        return $null
    } catch {
        return $null
    }
}

function Test-ChromeCurrent {
    param ([string] $Installed, [string] $Current)
    if (-not $Installed -or -not $Current) { return $false }
    try { return ([version]$Installed -ge [version]$Current) } catch { return $false }
}

$installed = Get-InstalledChromeVersion
$current = Get-CurrentChromeVersion

if ($CheckOnly) {
    ## Unknown current version counts as "current" so puppet does not fire an
    ## install it cannot verify. The boot-time run retries later anyway.
    if (-not $current -or (Test-ChromeCurrent -Installed $installed -Current $current)) { exit 0 }
    exit 1
}

Write-Log -message ('Update-GoogleChrome :: installed {0} / current stable {1}' -f $installed, $current) -severity 'DEBUG'

if (-not $current) {
    Write-Log -message ('Update-GoogleChrome :: version API unreachable, leaving Chrome {0} in place' -f $installed) -severity 'WARN'
    exit 0
}
if (Test-ChromeCurrent -Installed $installed -Current $current) {
    Write-Log -message ('Update-GoogleChrome :: Chrome {0} is current' -f $installed) -severity 'DEBUG'
    exit 0
}

$msi = Join-Path $env:TEMP 'googlechromestandaloneenterprise64.msi'
$log_dir = "$env:systemdrive\logs"
## msiexec returns 1622 if it cannot open its log file, so make sure the dir exists.
if (-not (Test-Path $log_dir)) { New-Item -Path $log_dir -ItemType Directory -Force | Out-Null }
$msi_log = Join-Path $log_dir 'googlechrome-msi.log'

for ($i = 1; $i -le $Tries; $i++) {
    try {
        if (Test-Path $msi) { Remove-Item $msi -Force -ErrorAction SilentlyContinue }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $msi_url -OutFile $msi -UseBasicParsing -TimeoutSec 600

        $proc = Start-Process -FilePath 'msiexec.exe' -Wait -PassThru -ArgumentList @(
            '/i', ('"{0}"' -f $msi), '/qn', '/norestart', '/l*v', ('"{0}"' -f $msi_log)
        )
        ## 3010 = success, reboot requested. Chrome does not need one, and nothing
        ## is running yet at this point in maintainsystem, so we do not take it.
        if ($proc.ExitCode -in 0, 3010) { break }
        Write-Log -message ('Update-GoogleChrome :: attempt {0}/{1} msiexec rc={2}' -f $i, $Tries, $proc.ExitCode) -severity 'WARN'
    } catch {
        Write-Log -message ('Update-GoogleChrome :: attempt {0}/{1} failed: {2}' -f $i, $Tries, $_.Exception.Message) -severity 'WARN'
    }
    ## 30s, 60s, 90s - rides out a transient CDN blip without hammering it.
    if ($i -lt $Tries) { Start-Sleep -Seconds (30 * $i) }
}
Remove-Item $msi -Force -ErrorAction SilentlyContinue

$after = Get-InstalledChromeVersion

if (Test-ChromeCurrent -Installed $after -Current $current) {
    Write-Log -message ('Update-GoogleChrome :: Chrome {0} -> {1}' -f $installed, $after) -severity 'DEBUG'
    exit 0
}
if ($after) {
    Write-Log -message ('Update-GoogleChrome :: Chrome still {0}, wanted {1}, after {2} attempts - continuing' -f $after, $current, $Tries) -severity 'WARN'
    exit 0
}

Write-Log -message ('Update-GoogleChrome :: Chrome is NOT installed and could not be installed (wanted {0})' -f $current) -severity 'ERROR'
exit 1
