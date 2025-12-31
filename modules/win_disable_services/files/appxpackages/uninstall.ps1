function Write-Log {
    param (
        [string] $message,
        [string] $severity = 'INFO',
        [string] $source   = 'BootStrap',
        [string] $logName  = 'Application'
    )

    if (!([Diagnostics.EventLog]::Exists($logName)) -or
        !([Diagnostics.EventLog]::SourceExists($source))) {
        New-EventLog -LogName $logName -Source $source
    }

    switch ($severity) {
        'DEBUG' { $entryType = 'SuccessAudit'; $eventId = 2; break }
        'WARN'  { $entryType = 'Warning';      $eventId = 3; break }
        'ERROR' { $entryType = 'Error';        $eventId = 4; break }
        default { $entryType = 'Information';  $eventId = 1; break }
    }

    Write-EventLog -LogName $logName -Source $source `
                   -EntryType $entryType -Category 0 -EventID $eventId `
                   -Message $message

    if ([Environment]::UserInteractive) {
        $fc = @{
            'Information' = 'White'
            'Error'       = 'Red'
            'Warning'     = 'DarkYellow'
            'SuccessAudit'= 'DarkGray'
        }[$entryType]
        Write-Host $message -ForegroundColor $fc
    }
}

function Ensure-OneDriveTaskCleanupHardeningTask {
    [CmdletBinding()]
    param()

    $dir  = 'C:\ProgramData\Hardening'
    $file = Join-Path $dir 'Remove-OneDriveScheduledTasks.ps1'

    Write-Log -message "OneDriveTasksHardening :: begin" -severity 'DEBUG'

    try {
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

        # Minimal self-contained script: uses schtasks.exe only and writes to Event Log using your source/logName.
        $payload = @'
function Write-Log {
    param (
        [string] $message,
        [string] $severity = 'INFO',
        [string] $source = 'MaintainSystem',
        [string] $logName = 'Application'
    )
    try {
        if (!([Diagnostics.EventLog]::Exists($logName)) -or !([Diagnostics.EventLog]::SourceExists($source))) {
            New-EventLog -LogName $logName -Source $source
        }
        switch ($severity) {
            'DEBUG' { $entryType = 'SuccessAudit'; $eventId = 2; break }
            'WARN'  { $entryType = 'Warning';      $eventId = 3; break }
            'ERROR' { $entryType = 'Error';        $eventId = 4; break }
            default { $entryType = 'Information';  $eventId = 1; break }
        }
        Write-EventLog -LogName $logName -Source $source -EntryType $entryType -Category 0 -EventID $eventId -Message $message
    } catch { }
}

try {
    $rows = @(schtasks.exe /Query /FO CSV /V 2>$null | ConvertFrom-Csv)
    $targets = $rows | Where-Object {
        ($_.TaskName -match '(?i)onedrive') -or
        (($_.'Task To Run') -and (($_.'Task To Run') -match '(?i)onedrive(\\.exe)?')) -or
        (($_.Actions) -and ($_.Actions -match '(?i)onedrive(\\.exe)?')) -or
        (($_.'Task Run') -and (($_.'Task Run') -match '(?i)onedrive(\\.exe)?')) -or
        (($_.Actions) -and ($_.Actions -match '(?i)OneDriveSetup\.exe|\\OneDrive\.exe')) -or
        (($_.'Task To Run') -and (($_.'Task To Run') -match '(?i)OneDriveSetup\.exe|\\OneDrive\.exe'))
    } | Select-Object -ExpandProperty TaskName -Unique

    foreach ($tn in $targets) {
        schtasks.exe /Delete /TN "$tn" /F 2>$null | Out-Null
    }

    Write-Log -message ("OneDriveTasksHardening :: removed {0} task(s)" -f ($targets.Count)) -severity 'INFO'
} catch {
    Write-Log -message ("OneDriveTasksHardening :: failed: {0}" -f $_.Exception.Message) -severity 'WARN'
}
'@

        Set-Content -Path $file -Value $payload -Encoding UTF8 -Force

        $taskName = 'Remove-OneDriveScheduledTasks'
        $taskPath = '\Hardening\'

        schtasks.exe /Delete /TN "$taskPath$taskName" /F 2>$null | Out-Null

        # Create: AtStartup
        schtasks.exe /Create /F /TN "$taskPath$taskName" `
            /SC ONSTART /RU SYSTEM /RL HIGHEST `
            /TR "powershell.exe -NoLogo -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$file`"" `
            2>$null | Out-Null

        # Add a second trigger: AtLogOn (any user)
        schtasks.exe /Create /F /TN "$taskPath$taskName-Logon" `
            /SC ONLOGON /RU SYSTEM /RL HIGHEST `
            /TR "powershell.exe -NoLogo -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$file`"" `
            2>$null | Out-Null

        Write-Log -message "OneDriveTasksHardening :: installed (ONSTART + ONLOGON)" -severity 'INFO'
    }
    catch {
        Write-Log -message ("OneDriveTasksHardening :: failed: {0}" -f $_.Exception.Message) -severity 'WARN'
    }
    finally {
        Write-Log -message "OneDriveTasksHardening :: end" -severity 'DEBUG'
    }
}

function Remove-OneDriveAggressive {
  [CmdletBinding()]
  param(
    [switch]$PurgeUserData
  )

  function Try-Run([scriptblock]$sb, [string]$onError, [string]$severity = 'WARN') {
    try { & $sb } catch { Write-Log -message "$onError $($_.Exception.Message)" -severity $severity -source 'BootStrap' -logName 'Application' }
  }

  Write-Log -message "1) Stop OneDrive-related processes" -severity 'INFO' -source 'BootStrap' -logName 'Application'

  $procNames = @("OneDrive","OneDriveStandaloneUpdater","OneDriveSetup")
  foreach ($p in $procNames) {
    Get-Process -Name $p -ErrorAction SilentlyContinue | ForEach-Object {
      $desc = "Process $($_.Name) (Id=$($_.Id))"
      Try-Run { Stop-Process -Id $_.Id -Force -ErrorAction Stop } "Failed stopping ${desc}:"
    }
  }

  Write-Log -message "2) Disable and remove OneDrive scheduled tasks" -severity 'INFO' -source 'BootStrap' -logName 'Application'

  Try-Run {
    $tasks = Get-ScheduledTask -ErrorAction Stop | Where-Object {
      $_.TaskName -like "OneDrive*" -or $_.TaskPath -like "*OneDrive*"
    }

    foreach ($t in $tasks) {
      $fullName = "$($t.TaskPath)$($t.TaskName)"
      Try-Run { Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction SilentlyContinue | Out-Null } "Failed disabling task ${fullName}:"
      Try-Run { Unregister-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -Confirm:$false -ErrorAction SilentlyContinue | Out-Null } "Failed unregistering task ${fullName}:"
    }

    if (-not $tasks) {
      Write-Log -message "No OneDrive scheduled tasks found." -severity 'INFO' -source 'BootStrap' -logName 'Application'
    }
  } "Could not enumerate scheduled tasks:"

  Write-Log -message "3) Uninstall OneDrive (winget if available, then built-in uninstallers)" -severity 'INFO' -source 'BootStrap' -logName 'Application'

  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if ($winget) {
    Try-Run {
      & winget uninstall --id Microsoft.OneDrive -e --accept-source-agreements --accept-package-agreements | Out-Null
    } "winget uninstall failed:"
  } else {
    Write-Log -message "winget not found; skipping winget uninstall." -severity 'DEBUG' -source 'BootStrap' -logName 'Application'
  }

  $setupPaths = @(
    Join-Path $env:SystemRoot "System32\OneDriveSetup.exe",
    Join-Path $env:SystemRoot "SysWOW64\OneDriveSetup.exe"
  ) | Select-Object -Unique

  foreach ($path in $setupPaths) {
    if (Test-Path $path) {
      Try-Run { Start-Process -FilePath $path -ArgumentList "/uninstall" -Wait -WindowStyle Hidden } "Failed running $path /uninstall:"
    } else {
      Write-Log -message "Not found: $path" -severity 'DEBUG' -source 'BootStrap' -logName 'Application'
    }
  }

  Write-Log -message "4) Remove OneDrive from startup/run hooks" -severity 'INFO' -source 'BootStrap' -logName 'Application'

  $runKeys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
  )

  foreach ($k in $runKeys) {
    if (Test-Path $k) {
      foreach ($name in @("OneDrive","OneDriveSetup","Microsoft OneDrive")) {
        Try-Run { Remove-ItemProperty -Path $k -Name $name -ErrorAction SilentlyContinue } "Failed removing Run key value ${k}\${name}:"
      }
    }
  }

  $startupFolders = @(
    Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup",
    Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\Startup"
  )

  foreach ($sf in $startupFolders) {
    if (Test-Path $sf) {
      Get-ChildItem -Path $sf -Filter "*OneDrive*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
        Try-Run { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue } "Failed removing startup shortcut $($_.FullName):"
      }
    }
  }

  Write-Log -message "5) Disable OneDrive via policy (prevents sign-in/sync)" -severity 'INFO' -source 'BootStrap' -logName 'Application'

  $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
  Try-Run {
    New-Item -Path $policyPath -Force | Out-Null
    New-ItemProperty -Path $policyPath -Name "DisableFileSyncNGSC" -PropertyType DWord -Value 1 -Force | Out-Null
  } "Failed setting DisableFileSyncNGSC policy:"

  Write-Log -message "6) Remove File Explorer integration (sidebar pin + namespace entries)" -severity 'INFO' -source 'BootStrap' -logName 'Application'

  $clsid = "{018D5C66-4533-4307-9B53-224DE2ED1FE6}"

  foreach ($k in @("HKCR:\CLSID\$clsid","HKCR:\Wow6432Node\CLSID\$clsid")) {
    Try-Run {
      New-Item -Path $k -Force | Out-Null
      New-ItemProperty -Path $k -Name "System.IsPinnedToNameSpaceTree" -PropertyType DWord -Value 0 -Force | Out-Null
    } "Failed setting nav pane pin value at ${k}:"
  }

  foreach ($k in @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$clsid",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$clsid",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$clsid"
  )) {
    if (Test-Path $k -PathType Container) {
      Try-Run { Remove-Item -Path $k -Recurse -Force -ErrorAction SilentlyContinue } "Failed removing namespace key ${k}:"
    }
  }

  Write-Log -message "7) Remove leftover folders (optional purge of user data)" -severity 'INFO' -source 'BootStrap' -logName 'Application'

  $folders = @(
    Join-Path $env:LOCALAPPDATA "Microsoft\OneDrive",
    Join-Path $env:PROGRAMDATA "Microsoft OneDrive",
    Join-Path $env:SystemDrive "OneDriveTemp"
  )

  if ($PurgeUserData) {
    $folders += (Join-Path $env:USERPROFILE "OneDrive")
  }

  foreach ($f in ($folders | Select-Object -Unique)) {
    if (Test-Path $f) {
      Try-Run { Remove-Item -LiteralPath $f -Recurse -Force -ErrorAction SilentlyContinue } "Failed removing folder ${f}:"
    }
  }

  Write-Log -message "8) Restart Explorer to apply UI changes" -severity 'INFO' -source 'BootStrap' -logName 'Application'

  Try-Run {
    Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Process explorer.exe
  } "Failed restarting Explorer:"

  Write-Log -message "OneDrive removal/disable steps completed. Recommend reboot to finalize." -severity 'INFO' -source 'BootStrap' -logName 'Application'
  if (-not $PurgeUserData) {
    Write-Log -message "NOTE: %UserProfile%\OneDrive was NOT deleted. Use -PurgeUserData to delete it." -severity 'WARN' -source 'BootStrap' -logName 'Application'
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
        "Microsoft.DesktopAppInstaller"   = @{ VDIState="Unchanged"; URL="https://apps.microsoft.com/detail/9NBLGGH4NNS1"; Description="Microsoft App Installer for Windows 10 makes sideloading Windows apps easy" }
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
        $null = $apps[$Key] # keep, in case you add logging later

        Get-AppxProvisionedPackage -Online |
            Where-Object { $_.PackageName -like ("*{0}*" -f $Key) } |
            Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Out-Null

        Get-AppxPackage -AllUsers -Name ("*{0}*" -f $Key) |
            Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
            Out-Null

        Get-AppxPackage -Name ("*{0}*" -f $Key) |
            Remove-AppxPackage -ErrorAction SilentlyContinue |
            Out-Null
    }

    $paths = @(
        "$env:SystemRoot\System32\OneDriveSetup.exe",
        "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    )

    foreach ($p in $paths) {
        if (Test-Path $p) {
            Start-Process $p -ArgumentList '/uninstall' -Wait -NoNewWindow
        }
    }

    Ensure-OneDriveTaskCleanupHardeningTask
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

    # Best-effort: give it a moment to stop (can be sticky during provisioning)
    for ($i=0; $i -lt 10; $i++) {
        $s = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($null -eq $s -or $s.Status -eq 'Stopped') { break }
        Start-Sleep -Seconds 1
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
    if ($null -eq $svc) { return $true }

    # Success condition: Disabled. It may still be Running during early provisioning.
    if ($svc.StartType.ToString() -eq 'Disabled') {
        if ($svc.Status -ne 'Stopped') {
            Write-Log -message ("uninstall_appx_packages :: AppXSvc is Disabled but currently {0}. Will be enforced at next boot." -f $svc.Status) -severity 'WARN'
        }
        return $true
    }

    return $false
}

Write-Log -message 'uninstall_appx_packages :: begin' -severity 'DEBUG'

Write-Log -message 'uninstall_appx_packages :: Remove-PreinstalledAppxPackages' -severity 'DEBUG'
Remove-PreinstalledAppxPackages

Write-Log -message 'uninstall_appx_packages :: Disable-AppXSvcCore' -severity 'DEBUG'
Disable-AppXSvcCore

Write-Log -message 'uninstall_appx_packages :: Ensure-AppXSvcHardeningTask' -severity 'DEBUG'
Ensure-AppXSvcHardeningTask

if (-not (Test-AppXSvcDisabled)) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    $status    = if ($svc) { $svc.Status }    else { 'Missing' }
    $startType = if ($svc) { $svc.StartType } else { 'Missing' }

    Write-Log -message ("uninstall_appx_packages :: AppXSvc is NOT disabled. Status: {0}, StartType: {1}" -f $status, $startType) -severity 'ERROR'
    throw "AppXSvc is NOT disabled. Status: $status, StartType: $startType"
}

Write-Log -message 'uninstall_appx_packages :: complete (AppXSvc disabled)' -severity 'DEBUG'
