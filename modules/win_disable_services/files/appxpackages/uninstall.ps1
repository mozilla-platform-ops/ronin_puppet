#requires -RunAsAdministrator

# Lab-only Windows 11 24H2 hardening:
# - Remove predefined AppX packages (inlined from ronin uninstall.ps1)
# - Disable AppXSvc (service + registry Start=4)
# - Install startup scheduled task (SYSTEM) to re-enforce disable every boot
# - Validate AppXSvc is disabled; exit 0 on success, 1 on failure

$ErrorActionPreference = 'Stop'

$svcName    = 'AppXSvc'
$svcKeyPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\AppXSvc'

function Remove-PreinstalledAppxPackages {
    [CmdletBinding()]
    param()

    $apps = @{
        "Bing Search" = @{
            VDIState    = "Unchanged"
            URL         = "https://apps.microsoft.com/detail/9nzbf4gt040c"
            Description = "Web Search from Microsoft Bing provides web results and answers in Windows Search"
        }
        "Clipchamp.Clipchamp" = @{
            VDIState    = "Unchanged"
            URL         = "https://apps.microsoft.com/detail/9p1j8s7ccwwt?hl=en-us&gl=US"
            Description = "Create videos with a few clicks"
        }
        "Microsoft.549981C3F5F10" = @{
            VDIState    = "Unchanged"
            URL         = "https://apps.microsoft.com/detail/cortana/9NFFX4SZZ23L?hl=en-us&gl=US"
            Description = "Cortana (could not update)"
        }
        "Microsoft.BingNews" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/microsoft-news/9wzdncrfhvfw"
            Description = "Microsoft News app"
        }
        "Microsoft.BingWeather" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/msn-weather/9wzdncrfj3q2"
            Description = "MSN Weather app"
        }
        "Microsoft.DesktopAppInstaller" = @{
            VDIState    = "Unchanged"
            URL         = "https://apps.microsoft.com/detail/9NBLGGH4NNS1"
            Description = "Microsoft App Installer for Windows 10 makes sideloading Windows apps easy"
        }
        "Microsoft.GetHelp" = @{
            VDIState    = "Unchanged"
            URL         = "https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/customize-get-help-app"
            Description = "App that facilitates free support for Microsoft products"
        }
        "Microsoft.Getstarted" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/microsoft-tips/9wzdncrdtbjj"
            Description = "Windows 10 tips app"
        }
        "Microsoft.MicrosoftOfficeHub" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/office/9wzdncrd29v9"
            Description = "Office UWP app suite"
        }
        "Microsoft.Office.OneNote" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/onenote-for-windows-10/9wzdncrfhvjl"
            Description = "Office UWP OneNote app"
        }
        "Microsoft.MicrosoftSolitaireCollection" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/microsoft-solitaire-collection/9wzdncrfhwd2"
            Description = "Solitaire suite of games"
        }
        "Microsoft.MicrosoftStickyNotes" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/microsoft-sticky-notes/9nblggh4qghw"
            Description = "Note-taking app"
        }
        "Microsoft.OutlookForWindows" = @{
            VDIState    = "Unchanged"
            URL         = "https://apps.microsoft.com/detail/9NRX63209R7B?hl=en-us&gl=US"
            Description = "A best-in-class email experience that is free for anyone with Windows"
        }
        "Microsoft.MSPaint" = @{
            VDIState    = "Unchanged"
            URL         = "https://apps.microsoft.com/store/detail/paint-3d/9NBLGGH5FV99"
            Description = "Paint 3D app (not Classic Paint app)"
        }
        "Microsoft.Paint" = @{
            VDIState    = "Unchanged"
            URL         = "https://apps.microsoft.com/detail/9PCFS5B6T72H"
            Description = "Classic Paint app"
        }
        "Microsoft.People" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/microsoft-people/9nblggh10pg8"
            Description = "Contact management app"
        }
        "Microsoft.PowerAutomateDesktop" = @{
            VDIState    = "Unchanged"
            URL         = "https://flow.microsoft.com/en-us/desktop/"
            Description = "Power Automate Desktop app. Record desktop and web actions in a single flow"
        }
        "Microsoft.ScreenSketch" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/snip-sketch/9mz95kl8mr0l"
            Description = "Snip and Sketch app"
        }
        "Microsoft.SkypeApp" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/skype/9wzdncrfj364"
            Description = "Instant message, voice or video call app"
        }
        "Microsoft.StorePurchaseApp" = @{
            VDIState    = "Unchanged"
            URL         = ""
            Description = "Store purchase app helper"
        }
        "Microsoft.Todos" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/microsoft-to-do-lists-tasks-reminders/9nblggh5r558"
            Description = "Microsoft To Do makes it easy to plan your day and manage your life"
        }
        "Microsoft.WinDbg.Fast" = @{
            VDIState    = "Unchanged"
            URL         = "https://apps.microsoft.com/detail/9PGJGD53TN86?hl=en-us&gl=US"
            Description = "Microsoft WinDbg"
        }
        "Microsoft.Windows.DevHome" = @{
            VDIState    = "Unchanged"
            URL         = "https://learn.microsoft.com/en-us/windows/dev-home/"
            Description = "Dev Home dashboard"
        }
        "Microsoft.Windows.Photos" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/microsoft-photos/9wzdncrfjbh4"
            Description = "Photo and video editor"
        }
        "Microsoft.WindowsAlarms" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/windows-alarms-clock/9wzdncrfj3pr"
            Description = "Alarms, world clock, timer, stopwatch"
        }
        "Microsoft.WindowsCalculator" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/windows-calculator/9wzdncrfhvn5"
            Description = "Microsoft Calculator app"
        }
        "Microsoft.WindowsCamera" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/windows-camera/9wzdncrfjbbg"
            Description = "Camera app"
        }
        "microsoft.windowscommunicationsapps" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/mail-and-calendar/9wzdncrfhvqm"
            Description = "Mail & Calendar apps"
        }
        "Microsoft.WindowsFeedbackHub" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/feedback-hub/9nblggh4r32n"
            Description = "Feedback Hub"
        }
        "Microsoft.WindowsMaps" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/windows-maps/9wzdncrdtbvb"
            Description = "Microsoft Maps app"
        }
        "Microsoft.WindowsNotepad" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/windows-notepad/9msmlrh6lzf3"
            Description = "Notepad (Store version)"
        }
        "Microsoft.WindowsStore" = @{
            VDIState    = "Unchanged"
            URL         = "https://blogs.windows.com/windowsexperience/2021/06/24/building-a-new-open-microsoft-store-on-windows-11/"
            Description = "Windows Store app"
        }
        "Microsoft.WindowsSoundRecorder" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/windows-voice-recorder/9wzdncrfhwkn"
            Description = "Voice recorder"
        }
        "Microsoft.WindowsTerminal" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/windows-terminal/9n0dx20hk701"
            Description = "Windows Terminal"
        }
        "Microsoft.Winget.Platform.Source" = @{
            VDIState    = "Unchanged"
            URL         = "https://learn.microsoft.com/en-us/windows/package-manager/winget/"
            Description = "Winget (Windows Package Manager) source"
        }
        "Microsoft.Xbox.TCUI" = @{
            VDIState    = "Unchanged"
            URL         = "https://docs.microsoft.com/en-us/gaming/xbox-live/features/general/tcui/live-tcui-overview"
            Description = "Xbox Title Callable UI"
        }
        "Microsoft.XboxIdentityProvider" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/xbox-identity-provider/9wzdncrd1hkw"
            Description = "Xbox Identity Provider"
        }
        "Microsoft.XboxSpeechToTextOverlay" = @{
            VDIState    = "Unchanged"
            URL         = "https://support.xbox.com/help/account-profile/accessibility/use-game-chat-transcription"
            Description = "Xbox game chat transcription"
        }
        "Microsoft.YourPhone" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/Your-phone/9nmpj99vjbwv"
            Description = "Phone Link"
        }
        "Microsoft.ZuneMusic" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/groove-music/9wzdncrfj3pt"
            Description = "Groove Music"
        }
        "Microsoft.ZuneVideo" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/movies-tv/9wzdncrfj3p2"
            Description = "Movies & TV"
        }
        "MicrosoftCorporationII.QuickAssist" = @{
            VDIState    = "Unchanged"
            URL         = "https://apps.microsoft.com/detail/9P7BP5VNWKX5?hl=en-us&gl=US"
            Description = "Quick Assist"
        }
        "MicrosoftWindows.Client.WebExperience" = @{
            VDIState    = "Unchanged"
            URL         = ""
            Description = "Windows 11 Widgets / Web Experience"
        }
        "Microsoft.XboxApp" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/store/apps/9wzdncrfjbd8"
            Description = "Xbox Console Companion"
        }
        "Microsoft.MixedReality.Portal" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/mixed-reality-portal/9ng1h8b3zc7m"
            Description = "Mixed Reality Portal"
        }
        "Microsoft.Microsoft3DViewer" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/p/3d-viewer/9nblggh42ths"
            Description = "3D Viewer"
        }
        "MicrosoftTeams" = @{
            VDIState    = "Unchanged"
            URL         = "https://apps.microsoft.com/detail/xp8bt8dw290mpq"
            Description = "Microsoft Teams"
        }
        "MSTeams" = @{
            VDIState    = "Unchanged"
            URL         = "https://apps.microsoft.com/detail/xp8bt8dw290mpq"
            Description = "Microsoft Teams (alt id)"
        }
        "Microsoft.OneDriveSync" = @{
            VDIState    = "Unchanged"
            URL         = "https://docs.microsoft.com/en-us/onedrive/one-drive-sync"
            Description = "OneDrive sync app"
        }
        "Microsoft.Wallet" = @{
            VDIState    = "Unchanged"
            URL         = "https://www.microsoft.com/en-us/payments"
            Description = "Microsoft Pay"
        }
    }

    foreach ($Key in $apps.Keys) {
        $Item = $apps[$Key]

        # Provisioned (for new users)
        Get-AppxProvisionedPackage -Online |
            Where-Object { $_.PackageName -like ("*{0}*" -f $Key) } |
            Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Out-Null

        # All users
        Get-AppxPackage -AllUsers -Name ("*{0}*" -f $Key) |
            Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
            Out-Null

        # Current user
        Get-AppxPackage -Name ("*{0}*" -f $Key) |
            Remove-AppxPackage -ErrorAction SilentlyContinue |
            Out-Null
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
$svcKeyPath = "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\AppXSvc"

try {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($null -ne $svc) {
        if ($svc.Status -ne "Stopped") {
            Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
        }
        Set-Service -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue
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
        -Argument "-NoLogo -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$hardeningFile`""
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

    if ($null -eq $svc) {
        return $true
    }

    $startType = $svc.StartType.ToString()
    if ($svc.Status -eq 'Stopped' -and $startType -eq 'Disabled') {
        return $true
    }

    return $false
}

# --- Main flow ---

Remove-PreinstalledAppxPackages
Disable-AppXSvcCore
Ensure-AppXSvcHardeningTask

if (-not (Test-AppXSvcDisabled)) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    $status    = if ($svc) { $svc.Status }    else { 'Missing' }
    $startType = if ($svc) { $svc.StartType } else { 'Missing' }

    Write-Error "AppXSvc is NOT disabled. Status: $status, StartType: $startType"
    exit 1
}

exit 0
