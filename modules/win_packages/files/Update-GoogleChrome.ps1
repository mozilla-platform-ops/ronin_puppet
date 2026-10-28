<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

RELOPS-2575: install/update hardware Chrome directly from Google's enterprise MSI.
The community Chocolatey feed rate-limited the shared MDC1 IP and triggered PXE loops.

The MSI can lag Google's stable-channel API, so compare its ETag and size with the
last installed artifact instead of treating that API as an installation target.
Last-Modified varies between CDN edges and must not trigger a reinstall.

Exit 0 when current or an existing Chrome survives an update failure. Exit 1 when
Chrome is absent and installation fails. This script never requests PXE or reboot.
#>
[CmdletBinding()]
param (
    # Report only: exit 0 when Chrome is already current, 1 when work is needed.
    # Used as the `unless` for the puppet exec so the check lives in one place.
    [switch] $CheckOnly,

    [ValidateRange(1, 3)]
    [int] $Tries = 3
)

$ErrorActionPreference = 'Stop'
## A progress bar turns the 167 MB download into a crawl under WinPS 5.1.
$ProgressPreference = 'SilentlyContinue'

$msi_url = 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi'
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
    param ($Headers)
    if (-not $Headers) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $head = Invoke-WebRequest -Uri $msi_url -Method Head -UseBasicParsing -TimeoutSec 30
            $Headers = $head.Headers
        } catch {
            return $null
        }
    }
    $etag = @($Headers['ETag'])[0]
    $len = @($Headers['Content-Length'])[0]
    # Length alone cannot distinguish different releases of the same size.
    if (-not $etag -or -not $len) { return $null }
    return ('{0}|{1}' -f $etag, $len)
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

Write-Log -message ('Update-GoogleChrome :: installed {0} | msi {1} | last installed msi {2}' -f $installed, $fingerprint, $last_installed) -severity 'DEBUG'

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
        $download = Invoke-WebRequest -Uri $msi_url -OutFile $msi -PassThru -UseBasicParsing -TimeoutSec 600
        # Record the downloaded artifact, which may have changed since the HEAD request.
        $fingerprint = Get-MsiFingerprint -Headers $download.Headers

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
    ## Wait 30s then 60s between attempts; never sleep after the last attempt.
    if ($i -lt $Tries) { Start-Sleep -Seconds (30 * $i) }
}
Remove-Item $msi -Force -ErrorAction SilentlyContinue

$after = Get-InstalledChromeVersion

if ($install_ok -and $after) {
    ## Record WHICH build we installed so later boots skip the download until Google
    ## actually rotates the artifact. Written only after a successful install, so a
    ## failed run retries next boot instead of marking itself done.
    ## Only store a fingerprint when the downloaded response provided one.
    if ($fingerprint) {
        if (-not (Test-Path $ronin_key)) { New-Item -Path $ronin_key -Force | Out-Null }
        Set-ItemProperty -Path $ronin_key -Name $fp_value -Value $fingerprint
    }
    else {
        Write-Log -message 'Update-GoogleChrome :: installed, but the MSI response had no fingerprint; re-checking next boot' -severity 'WARN'
    }
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
