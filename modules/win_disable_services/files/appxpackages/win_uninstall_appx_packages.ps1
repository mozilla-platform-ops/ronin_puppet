# win_uninstall_appx_packages.ps1
# AppX removal ONLY (no service management)

$Script:Version = "win_uninstall_appx_packages.ps1 2026-02-20 appx-only v1"
Write-Output "uninstall_appx_packages :: starting ($Script:Version)"

function Write-Log {
    param (
        [string] $message,
        [ValidateSet('DEBUG','INFO','WARN','ERROR')]
        [string] $severity = 'INFO',
        [string] $source   = 'BootStrap',
        [string] $logName  = 'Application'
    )

    $entryType = 'Information'
    $eventId   = 1

    switch ($severity) {
        'DEBUG' { $entryType = 'SuccessAudit'; $eventId = 2; break }
        'WARN'  { $entryType = 'Warning';      $eventId = 3; break }
        'ERROR' { $entryType = 'Error';        $eventId = 4; break }
        default { $entryType = 'Information';  $eventId = 1; break }
    }

    # Always emit to stdout so Puppet logoutput captures it
    try { Write-Output $message } catch { }

    # Best-effort event log creation
    try {
        if (!([Diagnostics.EventLog]::Exists($logName)) -or
            !([Diagnostics.EventLog]::SourceExists($source))) {
            New-EventLog -LogName $logName -Source $source -ErrorAction SilentlyContinue | Out-Null
        }
    } catch { }

    try {
        Write-EventLog -LogName $logName -Source $source `
            -EntryType $entryType -Category 0 -EventID $eventId `
            -Message $message -ErrorAction SilentlyContinue
    } catch { }

    if ([Environment]::UserInteractive) {
        $fc = @{
            'Information'  = 'White'
            'Error'        = 'Red'
            'Warning'      = 'DarkYellow'
            'SuccessAudit' = 'DarkGray'
        }[$entryType]
        Write-Host $message -ForegroundColor $fc
    }
}

# IMPORTANT: use 'Continue' so normal AppX noise doesn't hard-fail Puppet
$ErrorActionPreference = 'Continue'

# Optional transcript (works even if Puppet swallows stdout)
$Script:TranscriptPath = $null
try {
    $logDir = "C:\ProgramData\PuppetLabs\ronin\logs"
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

    $ts = Get-Date -Format "yyyyMMdd-HHmmss"
    $Script:TranscriptPath = Join-Path $logDir "uninstall_appx_packages-$ts.log"
    Start-Transcript -Path $Script:TranscriptPath -Force | Out-Null
    Write-Log -message "uninstall_appx_packages :: transcript: $Script:TranscriptPath" -severity "DEBUG"
} catch { }

function Stop-TranscriptSafe {
    try { Stop-Transcript | Out-Null } catch { }
}

function Test-HEVCCodecPresent {
    [CmdletBinding()]
    param()

    # Installed packages (any users)
    try {
        $installed = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -like "*HEVC*" -or $_.PackageFamilyName -like "*HEVC*"
            }
        if ($installed) { return $true }
    } catch { }

    # Provisioned packages (image-level)
    try {
        $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object {
                $_.DisplayName -like "*HEVC*" -or $_.PackageName -like "*HEVC*"
            }
        if ($prov) { return $true }
    } catch { }

    return $false
}

function Ensure-HEVCCodec {
    [CmdletBinding()]
    param(
        [int]$TimeoutSeconds = 600
    )

    Write-Log -message "Ensure-HEVCCodec :: checking HEVC codec extension presence" -severity "DEBUG"

    if (Test-HEVCCodecPresent) {
        Write-Log -message "Ensure-HEVCCodec :: HEVC appears present (installed/provisioned)" -severity "INFO"
        return $true
    }

    Write-Log -message "Ensure-HEVCCodec :: HEVC not detected; attempting install BEFORE Store/AppXSvc changes" -severity "WARN"

    # Be kind to the Store/AppX stack before attempting install
    Wait-AppxIdle -TimeoutSeconds 600 -SleepSeconds 15 | Out-Null

    # We prefer "from Device Manufacturer" (often free) first, then the standard HEVC package.
    # winget IDs:
    #   9N4WGH0Z6VHQ = HEVC Video Extensions from Device Manufacturer
    #   9NMZLZ57R3T7 = HEVC Video Extensions
    $candidates = @("9N4WGH0Z6VHQ", "9NMZLZ57R3T7")

    # Ensure winget is present
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Log -message "Ensure-HEVCCodec :: winget.exe not found; cannot install from Microsoft Store. (Consider keeping DesktopAppInstaller or provisioning HEVC offline.)" -severity "ERROR"
        return $false
    }

    foreach ($id in $candidates) {
        Write-Log -message "Ensure-HEVCCodec :: attempting winget install: $id" -severity "INFO"

        $ok = Invoke-WithTimeout -TimeoutSeconds $TimeoutSeconds -ScriptBlock ([scriptblock]::Create(@"
`$ErrorActionPreference = 'Continue'
try {
    # -h = hidden (no UI), best-effort for CI
    & winget.exe install $id --source msstore --accept-package-agreements --accept-source-agreements -h
} catch { }
"@))

        # Give AppX a moment to settle then re-check
        Wait-AppxIdle -TimeoutSeconds 600 -SleepSeconds 15 | Out-Null

        if (Test-HEVCCodecPresent) {
            Write-Log -message "Ensure-HEVCCodec :: HEVC detected after install attempt ($id)" -severity "INFO"
            return $true
        }

        if (-not $ok) {
            Write-Log -message "Ensure-HEVCCodec :: winget attempt timed out for $id" -severity "WARN"
        } else {
            Write-Log -message "Ensure-HEVCCodec :: install attempt finished but HEVC still not detected for $id" -severity "WARN"
        }
    }

    Write-Log -message "Ensure-HEVCCodec :: failed to install HEVC via winget/msstore; proceeding (but HEVC mochitests may fail)" -severity "ERROR"
    return $false
}

# Wait for likely-update activity to calm down (lightweight; does NOT depend on services being stopped)
function Wait-AppxIdle {
    [CmdletBinding()]
    param(
        [int]$TimeoutSeconds = 600,
        [int]$SleepSeconds   = 15
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    $procNames = @(
        "TiWorker",            # Windows Modules Installer Worker
        "TrustedInstaller",    # TrustedInstaller.exe
        "MoUsoCoreWorker",     # Update Orchestrator worker
        "wsappx"               # Store/AppX host (often appears during activity)
    )

    while ((Get-Date) -lt $deadline) {
        $busy = $false
        foreach ($p in $procNames) {
            try {
                if (Get-Process -Name $p -ErrorAction SilentlyContinue) { $busy = $true; break }
            } catch { }
        }

        if (-not $busy) {
            Write-Log -message "Wait-AppxIdle :: appears idle" -severity "DEBUG"
            return $true
        }

        Write-Log -message "Wait-AppxIdle :: busy (waiting $SleepSeconds s)" -severity "DEBUG"
        Start-Sleep -Seconds $SleepSeconds
    }

    Write-Log -message "Wait-AppxIdle :: timed out after $TimeoutSeconds seconds; proceeding anyway" -severity "WARN"
    return $false
}

# Run a block with a timeout so a single AppX call can’t hang the whole run
function Invoke-WithTimeout {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][scriptblock]$ScriptBlock,
        [int]$TimeoutSeconds = 180
    )

    $job = Start-Job -ScriptBlock $ScriptBlock
    try {
        if (Wait-Job $job -Timeout $TimeoutSeconds) {
            Receive-Job $job -ErrorAction SilentlyContinue | Out-Null
            return $true
        } else {
            try { Stop-Job $job -Force -ErrorAction SilentlyContinue | Out-Null } catch { }
            Write-Log -message "Invoke-WithTimeout :: timed out after $TimeoutSeconds seconds" -severity "WARN"
            return $false
        }
    } finally {
        try { Remove-Job $job -Force -ErrorAction SilentlyContinue | Out-Null } catch { }
    }
}

function Remove-PreinstalledAppxPackages {
    [CmdletBinding()]
    param()

    $apps = @{
        "Bing Search"                     = @{ }
        "Clipchamp.Clipchamp"             = @{ }
        "Microsoft.549981C3F5F10"         = @{ }
        "Microsoft.BingNews"              = @{ }
        "Microsoft.BingWeather"           = @{ }
        "Microsoft.GetHelp"               = @{ }
        "Microsoft.Getstarted"            = @{ }
        "Microsoft.MicrosoftOfficeHub"    = @{ }
        "Microsoft.Office.OneNote"        = @{ }
        "Microsoft.MicrosoftSolitaireCollection" = @{ }
        "Microsoft.MicrosoftStickyNotes"  = @{ }
        "Microsoft.OutlookForWindows"     = @{ }
        "Microsoft.MSPaint"               = @{ }
        "Microsoft.Paint"                 = @{ }
        "Microsoft.People"                = @{ }
        "Microsoft.PowerAutomateDesktop"  = @{ }
        "Microsoft.ScreenSketch"          = @{ }
        "Microsoft.SkypeApp"              = @{ }
        "Microsoft.StorePurchaseApp"      = @{ }
        "Microsoft.Todos"                 = @{ }
        "Microsoft.WinDbg.Fast"           = @{ }
        "Microsoft.Windows.DevHome"       = @{ }
        "Microsoft.Windows.Photos"        = @{ }
        "Microsoft.WindowsAlarms"         = @{ }
        "Microsoft.WindowsCalculator"     = @{ }
        "Microsoft.WindowsCamera"         = @{ }
        "microsoft.windowscommunicationsapps" = @{ }
        "Microsoft.WindowsFeedbackHub"    = @{ }
        "Microsoft.WindowsMaps"           = @{ }
        "Microsoft.WindowsNotepad"        = @{ }
        "Microsoft.WindowsStore"          = @{ }
        "Microsoft.WindowsSoundRecorder"  = @{ }
        "Microsoft.Winget.Platform.Source"= @{ }
        "Microsoft.Xbox.TCUI"             = @{ }
        "Microsoft.XboxIdentityProvider"  = @{ }
        "Microsoft.XboxSpeechToTextOverlay" = @{ }
        "Microsoft.YourPhone"             = @{ }
        "Microsoft.ZuneMusic"             = @{ }
        "Microsoft.ZuneVideo"             = @{ }
        "MicrosoftCorporationII.QuickAssist" = @{ }
        "MicrosoftWindows.Client.WebExperience" = @{ }
        "Microsoft.XboxApp"               = @{ }
        "Microsoft.MixedReality.Portal"   = @{ }
        "Microsoft.Microsoft3DViewer"     = @{ }
        "MicrosoftTeams"                  = @{ }
        "MSTeams"                         = @{ }
        "Microsoft.OneDriveSync"          = @{ }
        "Microsoft.Wallet"                = @{ }
    }

    foreach ($Key in $apps.Keys) {
        Write-Log -message ("uninstall_appx_packages :: removing AppX match: {0}" -f $Key) -severity 'DEBUG'

        # Run each key's removal in a job w/ timeout so we never hang forever.
        $safeKey = $Key.Replace("'","''")

        $ok = Invoke-WithTimeout -TimeoutSeconds 180 -ScriptBlock ([scriptblock]::Create(@"
`$ErrorActionPreference = 'Continue'
Import-Module Appx -ErrorAction SilentlyContinue | Out-Null

`$Key = '$safeKey'

# Provisioned packages (image-level)
try {
    Get-AppxProvisionedPackage -Online -ErrorAction Stop |
        Where-Object { `$_.PackageName -like ("*{0}*" -f `$Key) } |
        ForEach-Object {
            `$pkgName = `$_.PackageName
            try { Remove-AppxProvisionedPackage -Online -PackageName `$pkgName -ErrorAction Stop | Out-Null } catch { }
        }
} catch { }

# Installed packages (all users)
try {
    Get-AppxPackage -AllUsers -Name ("*{0}*" -f `$Key) -ErrorAction SilentlyContinue |
        ForEach-Object {
            `$full = `$_.PackageFullName
            try { Remove-AppxPackage -AllUsers -Package `$full -ErrorAction Stop | Out-Null } catch { }
        }
} catch { }

# Installed packages (current user)
try {
    Get-AppxPackage -Name ("*{0}*" -f `$Key) -ErrorAction SilentlyContinue |
        ForEach-Object {
            `$full = `$_.PackageFullName
            try { Remove-AppxPackage -Package `$full -ErrorAction Stop | Out-Null } catch { }
        }
} catch { }
"@))

        if (-not $ok) {
            Write-Log -message ("uninstall_appx_packages :: timeout while removing key: {0}" -f $Key) -severity 'WARN'
        }
    }
}

# --- Main ---------------------------------------------------------------
## Ensure HEVC is aviable before we start uninstalling AppX packages
## https://bugzilla.mozilla.org/show_bug.cgi?id=2013985
Ensure-HEVCCodec
try {
    Write-Log -message 'uninstall_appx_packages :: begin' -severity 'DEBUG'

    Write-Log -message 'uninstall_appx_packages :: Wait-AppxIdle' -severity 'DEBUG'
    Wait-AppxIdle -TimeoutSeconds 600 -SleepSeconds 15 | Out-Null

    Write-Log -message 'uninstall_appx_packages :: Remove-PreinstalledAppxPackages' -severity 'DEBUG'
    Remove-PreinstalledAppxPackages

    Write-Log -message 'uninstall_appx_packages :: complete' -severity 'DEBUG'
    Stop-TranscriptSafe
    exit 0
}
catch {
    $msg = "uninstall_appx_packages :: FATAL: $($_.Exception.ToString())"
    try { Write-Output $msg } catch { }
    Write-Log -message $msg -severity 'ERROR'
    Stop-TranscriptSafe
    exit 1
}
