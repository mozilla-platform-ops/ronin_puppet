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

    # Best-effort event log creation (avoid terminating failures / races)
    try {
        if (!([Diagnostics.EventLog]::Exists($logName)) -or
            !([Diagnostics.EventLog]::SourceExists($source))) {
            New-EventLog -LogName $logName -Source $source -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {
        # ignore
    }

    try {
        Write-EventLog -LogName $logName -Source $source `
            -EntryType $entryType -Category 0 -EventID $eventId `
            -Message $message -ErrorAction SilentlyContinue
    } catch {
        # ignore
    }

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

$svcName    = 'AppXSvc'
$svcKeyPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\AppXSvc'

function Remove-PreinstalledAppxPackages {
    [CmdletBinding()]
    param()

    $apps = @{
        "Bing Search"                     = @{ VDIState="Unchanged"; URL="https://apps.microsoft.com/detail/9nzbf4gt040c"; Description="Web Search from Microsoft Bing provides web results and answers in Windows Search" }
        "Clipchamp.Clipchamp"             = @{ VDIState="Unchanged"; URL="https://apps.microsoft.com/detail/9p1j8s7ccwwt?hl=en-us&gl=US"; Description="Create videos with a few clicks" }
        "Microsoft.549981C3F5F10"         = @{ VDIState="Unchanged"; URL="https://apps.microsoft.com/detail/cortana/9NFFX4SZZ23L?hl=en-us&gl=US"; Description="Cortana (could not update)" }
        "Microsoft.BingNews"              = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/microsoft-news/9wzdncrfhvfw"; Description="Microsoft News app" }
        "Microsoft.BingWeather"           = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/msn-weather/9wzdncrfj3q2"; Description="MSN Weather app" }
        ## Doesn't actually gets removed
        ## Comment out for now
        #"Microsoft.DesktopAppInstaller"   = @{ VDIState="Unchanged"; URL="https://apps.microsoft.com/detail/9NBLGGH4NNS1"; Description="Microsoft App Installer for Windows 10 makes sideloading Windows apps easy" }
        "Microsoft.GetHelp"               = @{ VDIState="Unchanged"; URL="https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/customize-get-help-app"; Description="App that facilitates free support for Microsoft products" }
        "Microsoft.Getstarted"            = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/microsoft-tips/9wzdncrdtbjj"; Description="Windows 10 tips app" }
        "Microsoft.MicrosoftOfficeHub"    = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/office/9wzdncrd29v9"; Description="Office UWP app suite" }
        "Microsoft.Office.OneNote"        = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/onenote-for-windows-10/9wzdncrfhvjl"; Description="Office UWP OneNote app" }
        "Microsoft.MicrosoftSolitaireCollection" = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/microsoft-solitaire-collection/9wzdncrfhwd2"; Description="Solitaire suite of games" }
        "Microsoft.MicrosoftStickyNotes"  = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/microsoft-sticky-notes/9nblggh4qghw"; Description="Note-taking app" }
        "Microsoft.OutlookForWindows"     = @{ VDIState="Unchanged"; URL="https://apps.microsoft.com/detail/9NRX63209R7B?hl=en-us&gl=US"; Description="New Outlook app" }
        "Microsoft.MSPaint"               = @{ VDIState="Unchanged"; URL="https://apps.microsoft.com/store/detail/paint-3d/9NBLGGH5FV99"; Description="Paint 3D app" }
        "Microsoft.Paint"                 = @{ VDIState="Unchanged"; URL="https://apps.microsoft.com/detail/9PCFS5B6T72H"; Description="Classic Paint app" }
        "Microsoft.People"                = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/microsoft-people/9nblggh10pg8"; Description="Contact management app" }
        "Microsoft.PowerAutomateDesktop"  = @{ VDIState="Unchanged"; URL="https://flow.microsoft.com/en-us/desktop/"; Description="Power Automate Desktop" }
        "Microsoft.ScreenSketch"          = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/snip-sketch/9mz95kl8mr0l"; Description="Snip and Sketch app" }
        "Microsoft.SkypeApp"              = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/skype/9wzdncrfj364"; Description="Skype app" }
        "Microsoft.StorePurchaseApp"      = @{ VDIState="Unchanged"; URL=""; Description="Store purchase app helper" }
        "Microsoft.Todos"                 = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/microsoft-to-do-lists-tasks-reminders/9nblggh5r558"; Description="Microsoft To Do" }
        "Microsoft.WinDbg.Fast"           = @{ VDIState="Unchanged"; URL="https://apps.microsoft.com/detail/9PGJGD53TN86?hl=en-us&gl=US"; Description="WinDbg" }
        "Microsoft.Windows.DevHome"       = @{ VDIState="Unchanged"; URL="https://learn.microsoft.com/en-us/windows/dev-home/"; Description="Dev Home dashboard" }
        "Microsoft.Windows.Photos"        = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/microsoft-photos/9wzdncrfjbh4"; Description="Photos app" }
        "Microsoft.WindowsAlarms"         = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/windows-alarms-clock/9wzdncrfj3pr"; Description="Alarms & Clock" }
        "Microsoft.WindowsCalculator"     = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/windows-calculator/9wzdncrfhvn5"; Description="Calculator" }
        "Microsoft.WindowsCamera"         = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/windows-camera/9wzdncrfjbbg"; Description="Camera" }
        "microsoft.windowscommunicationsapps" = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/mail-and-calendar/9wzdncrfhvqm"; Description="Mail & Calendar" }
        "Microsoft.WindowsFeedbackHub"    = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/feedback-hub/9nblggh4r32n"; Description="Feedback Hub" }
        "Microsoft.WindowsMaps"           = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/windows-maps/9wzdncrdtbvb"; Description="Maps" }
        "Microsoft.WindowsNotepad"        = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/windows-notepad/9msmlrh6lzf3"; Description="Notepad (Store)" }
        "Microsoft.WindowsStore"          = @{ VDIState="Unchanged"; URL="https://blogs.windows.com/windowsexperience/2021/06/24/building-a-new-open-microsoft-store-on-windows-11/"; Description="Microsoft Store" }
        "Microsoft.WindowsSoundRecorder"  = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/windows-voice-recorder/9wzdncrfhwkn"; Description="Voice Recorder" }
        "Microsoft.WindowsTerminal"       = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/windows-terminal/9n0dx20hk701"; Description="Windows Terminal" }
        "Microsoft.Winget.Platform.Source"= @{ VDIState="Unchanged"; URL="https://learn.microsoft.com/en-us/windows/package-manager/winget/"; Description="Winget source" }
        "Microsoft.Xbox.TCUI"             = @{ VDIState="Unchanged"; URL="https://docs.microsoft.com/en-us/gaming/xbox-live/features/general/tcui/live-tcui-overview"; Description="Xbox TCUI" }
        "Microsoft.XboxIdentityProvider"  = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/xbox-identity-provider/9wzdncrd1hkw"; Description="Xbox Identity Provider" }
        "Microsoft.XboxSpeechToTextOverlay" = @{ VDIState="Unchanged"; URL="https://support.xbox.com/help/account-profile/accessibility/use-game-chat-transcription"; Description="Xbox chat transcription" }
        "Microsoft.YourPhone"             = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/Your-phone/9nmpj99vjbwv"; Description="Phone Link" }
        "Microsoft.ZuneMusic"             = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/groove-music/9wzdncrfj3pt"; Description="Groove Music" }
        "Microsoft.ZuneVideo"             = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/movies-tv/9wzdncrfj3p2"; Description="Movies & TV" }
        "MicrosoftCorporationII.QuickAssist" = @{ VDIState="Unchanged"; URL="https://apps.microsoft.com/detail/9P7BP5VNWKX5?hl=en-us&gl=US"; Description="Quick Assist" }
        "MicrosoftWindows.Client.WebExperience" = @{ VDIState="Unchanged"; URL=""; Description="Windows 11 Web Experience" }
        "Microsoft.XboxApp"               = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/store/apps/9wzdncrfjbd8"; Description="Xbox Console Companion" }
        "Microsoft.MixedReality.Portal"   = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/mixed-reality-portal/9ng1h8b3zc7m"; Description="Mixed Reality Portal" }
        "Microsoft.Microsoft3DViewer"     = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/p/3d-viewer/9nblggh42ths"; Description="3D Viewer" }
        "MicrosoftTeams"                  = @{ VDIState="Unchanged"; URL="https://apps.microsoft.com/detail/xp8bt8dw290mpq"; Description="Microsoft Teams" }
        "MSTeams"                         = @{ VDIState="Unchanged"; URL="https://apps.microsoft.com/detail/xp8bt8dw290mpq"; Description="Microsoft Teams (alt id)" }
        "Microsoft.OneDriveSync"          = @{ VDIState="Unchanged"; URL="https://docs.microsoft.com/en-us/onedrive/one-drive-sync"; Description="OneDrive sync app" }
        "Microsoft.Wallet"                = @{ VDIState="Unchanged"; URL="https://www.microsoft.com/en-us/payments"; Description="Microsoft Pay" }
    }

    foreach ($Key in $apps.Keys) {
        try {
            Write-Log -message ("uninstall_appx_packages :: removing AppX match: {0}" -f $Key) -severity 'DEBUG'

            # Provisioned packages (image-level)
            try {
                Get-AppxProvisionedPackage -Online -ErrorAction Stop |
                    Where-Object { $_.PackageName -like ("*{0}*" -f $Key) } |
                    ForEach-Object {
                        $pkgName = $_.PackageName
                        try {
                            Remove-AppxProvisionedPackage -Online -PackageName $pkgName -ErrorAction Stop | Out-Null
                        } catch {
                            Write-Log -message ("Remove-AppxProvisionedPackage failed for {0}: {1}" -f $pkgName, $_.Exception.Message) -severity 'WARN'
                        }
                    }
            } catch {
                Write-Log -message ("Get/Remove provisioned package failed for key {0}: {1}" -f $Key, $_.Exception.Message) -severity 'WARN'
            }

            # Installed packages (all users)
            try {
                Get-AppxPackage -AllUsers -Name ("*{0}*" -f $Key) -ErrorAction SilentlyContinue |
                    ForEach-Object {
                        $full = $_.PackageFullName
                        try {
                            Remove-AppxPackage -AllUsers -Package $full -ErrorAction Stop | Out-Null
                        } catch {
                            Write-Log -message ("Remove-AppxPackage(-AllUsers) failed for {0}: {1}" -f $full, $_.Exception.Message) -severity 'WARN'
                        }
                    }
            } catch {
                Write-Log -message ("Get/Remove AppxPackage(-AllUsers) failed for key {0}: {1}" -f $Key, $_.Exception.Message) -severity 'WARN'
            }

            # Installed packages (current user)
            try {
                Get-AppxPackage -Name ("*{0}*" -f $Key) -ErrorAction SilentlyContinue |
                    ForEach-Object {
                        $full = $_.PackageFullName
                        try {
                            Remove-AppxPackage -Package $full -ErrorAction Stop | Out-Null
                        } catch {
                            Write-Log -message ("Remove-AppxPackage failed for {0}: {1}" -f $full, $_.Exception.Message) -severity 'WARN'
                        }
                    }
            } catch {
                Write-Log -message ("Get/Remove AppxPackage failed for key {0}: {1}" -f $Key, $_.Exception.Message) -severity 'WARN'
            }
        } catch {
            # Absolutely never let AppX errors terminate this script (Puppet signal should be AppXSvc-only)
            Write-Log -message ("Remove-PreinstalledAppxPackages unexpected failure for key {0}: {1}" -f $Key, $_.Exception.ToString()) -severity 'WARN'
            continue
        }
    }
}

function Disable-AppXSvcCore {
    [CmdletBinding()]
    param()

    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($null -ne $svc) {
        if ($svc.Status -ne 'Stopped') {
            Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
        }
        Set-Service -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue
    }

    # Extra-hard disable (best-effort): do NOT allow sc.exe exit code to poison overall script exit code
    try {
        & sc.exe config $svcName start= disabled | Out-Null
    } catch {
        # ignore
    } finally {
        $global:LASTEXITCODE = 0
    }

    # Registry is the source of truth for disabled start
    if (Test-Path $svcKeyPath) {
        New-ItemProperty -Path $svcKeyPath -Name Start -Value 4 -PropertyType DWord -Force | Out-Null
    }
}

function Ensure-AppXSvcHardeningTask {
    [CmdletBinding()]
    param()

    $hardeningDir  = 'C:\ProgramData\AppXLock'
    $hardeningFile = Join-Path $hardeningDir 'Disable-AppXSvc.ps1'

    if (-not (Test-Path $hardeningDir)) {
        New-Item -ItemType Directory -Path $hardeningDir -Force | Out-Null
    }

    $hardeningScript = @'
param()

$ErrorActionPreference = "SilentlyContinue"

$svcName    = "AppXSvc"
$svcKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Services\AppXSvc"

try {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($null -ne $svc) {
        if ($svc.Status -ne "Stopped") {
            Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
        }
        Set-Service -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue
    }

    # Best-effort: do NOT leak sc.exe exit code
    try {
        & sc.exe config $svcName start= disabled | Out-Null
    } catch {
        # ignore
    } finally {
        $global:LASTEXITCODE = 0
    }

    if (Test-Path $svcKeyPath) {
        New-ItemProperty -Path $svcKeyPath -Name Start -Value 4 -PropertyType DWord -Force | Out-Null
    }
} catch {
    # best-effort only
}
'@

    Set-Content -Path $hardeningFile -Value $hardeningScript -Encoding UTF8 -Force

    $action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$hardeningFile`""
    $trigger = New-ScheduledTaskTrigger -AtStartup

    $taskName = 'Hard-Disable-AppXSvc'
    $taskPath = '\Hardening\'

    Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false -ErrorAction SilentlyContinue

    Register-ScheduledTask -TaskName $taskName `
        -TaskPath $taskPath `
        -Action $action `
        -Trigger $trigger `
        -RunLevel Highest `
        -User 'SYSTEM' `
        -Force | Out-Null
}

function Test-AppXSvcDisabled {
    [CmdletBinding()]
    param()

    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($null -eq $svc) { return $true }

    # Registry is the most reliable indicator (Start=4)
    $regStart = $null
    try {
        $regStart = (Get-ItemProperty -Path $svcKeyPath -Name Start -ErrorAction SilentlyContinue).Start
    } catch { }

    $regDisabled = ($regStart -eq 4)

    # CIM is a helpful second signal (StartMode: Auto/Manual/Disabled)
    $cimDisabled = $false
    $cimStartMode = 'Unknown'
    try {
        $svcCim = Get-CimInstance Win32_Service -Filter "Name='$svcName'" -ErrorAction SilentlyContinue
        if ($svcCim) {
            $cimStartMode = $svcCim.StartMode
            $cimDisabled  = ($svcCim.StartMode -eq 'Disabled')
        }
    } catch { }

    if ($svc.Status -eq 'Stopped' -and ($regDisabled -or $cimDisabled)) {
        return $true
    }

    return $false
}

# --- Main flow ---------------------------------------------------------------

try {
    Write-Log -message 'uninstall_appx_packages :: begin' -severity 'DEBUG'

    Write-Log -message 'uninstall_appx_packages :: Remove-PreinstalledAppxPackages' -severity 'DEBUG'
    Remove-PreinstalledAppxPackages

    Write-Log -message 'uninstall_appx_packages :: Disable-AppXSvcCore' -severity 'DEBUG'
    Disable-AppXSvcCore

    Write-Log -message 'uninstall_appx_packages :: Ensure-AppXSvcHardeningTask' -severity 'DEBUG'
    Ensure-AppXSvcHardeningTask

    if (-not (Test-AppXSvcDisabled)) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        $status = if ($svc) { $svc.Status } else { 'Missing' }

        $regStart = $null
        try { $regStart = (Get-ItemProperty -Path $svcKeyPath -Name Start -ErrorAction SilentlyContinue).Start } catch { }
        $regStartStr = if ($null -ne $regStart) { $regStart } else { 'Missing' }

        $cimStartMode = 'Unknown'
        try {
            $svcCim = Get-CimInstance Win32_Service -Filter "Name='$svcName'" -ErrorAction SilentlyContinue
            if ($svcCim) { $cimStartMode = $svcCim.StartMode }
        } catch { }

        Write-Log -message ("uninstall_appx_packages :: AppXSvc is NOT disabled. Status: {0}, RegStart: {1}, CimStartMode: {2}" -f $status, $regStartStr, $cimStartMode) -severity 'ERROR'
        exit 2
    }

    Write-Log -message 'uninstall_appx_packages :: complete (AppXSvc disabled)' -severity 'DEBUG'
    exit 0
}
catch {
    Write-Log -message ("uninstall_appx_packages :: FATAL: {0}" -f $_.Exception.ToString()) -severity 'ERROR'
    exit 1
}
