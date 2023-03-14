function Write-Log {
    param (
        [string] $message,
        [string] $severity = 'INFO',
        [string] $source = 'BootStrap',
        [string] $logName = 'Application'
    )
    if (!([Diagnostics.EventLog]::Exists($logName)) -or !([Diagnostics.EventLog]::SourceExists($source))) {
        New-EventLog -LogName $logName -Source $source
    }
    switch ($severity) {
        'DEBUG' {
            $entryType = 'SuccessAudit'
            $eventId = 2
            break
        }
        'WARN' {
            $entryType = 'Warning'
            $eventId = 3
            break
        }
        'ERROR' {
            $entryType = 'Error'
            $eventId = 4
            break
        }
        default {
            $entryType = 'Information'
            $eventId = 1
            break
        }
    }
    Write-EventLog -LogName $logName -Source $source -EntryType $entryType -Category 0 -EventID $eventId -Message $message
    if ([Environment]::UserInteractive) {
        $fc = @{ 'Information' = 'White'; 'Error' = 'Red'; 'Warning' = 'DarkYellow'; 'SuccessAudit' = 'DarkGray' }[$entryType]
        Write-Host  -object $message -ForegroundColor $fc
    }
}

# From time to time we need to have the different releases of the same OS version
$release_key = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion')
$release_id = $release_key.ReleaseId
$win_os_build = [System.Environment]::OSVersion.Version.build

# OS caption
# Used to determine which KMS license for cloud workers
$caption = ((Get-WmiObject Win32_OperatingSystem).caption)
$caption = $caption.ToLower()
$os_caption = $caption -replace ' ', '_'

if ($os_caption -like "*windows_10*") {
    $os_version = ( -join ( "win_10_", $release_id))
}
elseif ($os_caption -like "*windows_11*") {
    $os_version = ( -join ( "win_11_", $release_id))
}
elseif ($os_caption -like "*2012*") {
    $os_version = "win_2012"
}
else {
    $os_version = $null
}

## Get the user that is to be provisioned
Write-Log -Message ('{0} :: Executing task-user-init - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'

try {
    $localuser = (Get-Content "C:\worker-runner\current-task-user.json" | ConvertFrom-Json -ErrorAction Stop).name
    Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Found current-task-user $localuser", (Get-Date).ToUniversalTime()) -severity 'DEBUG'
}
catch {
    Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Unable to find current task user", (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    exit 1
}

while (-not (Get-LocalUser -Name $localuser -ErrorAction SilentlyContinue)) {
    Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Waiting for $localuser to be created", (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    Start-Sleep -Seconds 5
}

switch ($os_version) {
    "win_11_2009" {
        ## Loading registry hive - https://stackoverflow.com/questions/25438409/reg-unload-and-new-key
        $regPath = "C:\Users\$localuser\ntuser.dat"
        Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Loading registry hive for $localuser", (Get-Date).ToUniversalTime()) -severity 'DEBUG'
        $regKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('Users', $env:COMPUTERNAME).OpenSubKey($regPath)
        if (-not $regKey) {
            Write-Error "Failed to load registry hive for user $localuser"
            exit 1
        }

        ## Disable windows security and maintenance notifications
        $Path1 = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance'
        if (-not (Test-Path $Path1)) {
            Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Creating Windows.SystemToast.SecurityAndMaintenance reg path", (Get-Date).ToUniversalTime()) -severity 'DEBUG'
            New-Item -Path $path1 -Force
        }
        Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Disabling Creating Windows.SystemToast.SecurityAndMaintenance", (Get-Date).ToUniversalTime()) -severity 'DEBUG'
        Set-ItemProperty -Path $Path1 -Name Enabled -Value 0

        ## Set Windows VisualFX

        <#
        ## Doesn't work https://www.reddit.com/r/PowerShell/comments/u3y4xd/change_visualfx_on_windows_11/
        ## Stackoverflow: https://stackoverflow.com/questions/9897310/can-you-change-the-visual-effects-performance-settings-from-an-application
        ## https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-systemparametersinfow
        #>

        ## Enable Scrollbars to always show
        Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Setting scrollbars to always show", (Get-Date).ToUniversalTime()) -severity 'DEBUG'
        New-ItemProperty -Path 'HKCU:\Control Panel\Accessibility' -Name 'DynamicScrollbars' -Value 0

        ## Prepare Chrome Profile
        ## Not needed due to only being required for hardware gpu testers
        if (test-path "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe") {
            Start-Process chrome
            Start-Sleep -s 30
            taskkill /F /IM chrome.exe /T
        }

        ## After all hkcu items are changed, restart explorer
        Stop-Process -f -ProcessName explorer

        ## Clean up handle(s)
        [gc]::Collect()
        [gc]::WaitForPendingFinalizers()

        $regKey.Close()
    }
    "win_2012" {
        ## prevent Git repos from being seen as unsafe after copied
        git config --global --add safe.directory '*'
    }
    Default {}
}
