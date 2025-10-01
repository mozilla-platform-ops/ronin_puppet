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

function Disable-OneDrive {
    [CmdletBinding()]
    param (
        
    )

    $ErrorActionPreference = 'SilentlyContinue'

    Stop-Process -Name OneDrive -Force
    Stop-Process -Name OneDriveSetup -Force
    Stop-Process -Name explorer -Force

    $pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive'
    New-Item -Path $pol -Force | Out-Null
    New-ItemProperty -Path $pol -Name 'DisableFileSyncNGSC' -PropertyType DWord -Value 1 -Force | Out-Null
    # Clean incorrect Wow6432Node path (if previously set)
    Remove-Item -Path 'HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\OneDrive' -Recurse -Force

    foreach ($rk in @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
        )) {
        if (Test-Path $rk) {
            $props = (Get-ItemProperty -Path $rk | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)
            foreach ($name in $props) {
                $val = (Get-ItemPropertyValue -Path $rk -Name $name)
                if ($val -match 'OneDriveSetup\.exe') {
                    Remove-ItemProperty -Path $rk -Name $name -Force
                }
            }
        }
    }

    Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object { $_.TaskName -like 'OneDrive*' -or $_.TaskPath -like '\Microsoft\OneDrive\*' } |
    Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

    $sys32 = "$env:WINDIR\System32\OneDriveSetup.exe"
    $wow64 = "$env:WINDIR\SysWOW64\OneDriveSetup.exe"
    if (Test-Path $sys32) { & $sys32 /uninstall }
    if (Test-Path $wow64) { & $wow64 /uninstall }

    Remove-Item -LiteralPath "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force
    Remove-Item -LiteralPath "$env:PROGRAMDATA\Microsoft OneDrive" -Recurse -Force
    Remove-Item -LiteralPath "$env:SYSTEMDRIVE\OneDriveTemp" -Recurse -Force
    if (Test-Path "$env:USERPROFILE\OneDrive") {
        if ((Get-ChildItem "$env:USERPROFILE\OneDrive" -Recurse | Measure-Object).Count -eq 0) {
            Remove-Item -LiteralPath "$env:USERPROFILE\OneDrive" -Recurse -Force
        }
    }

    Start-Process explorer.exe

}

function Disable-StorageSense {
    [CmdletBinding()]
    param (
        
    )
    
    try {
        New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\StorageSense' -Name 'AllowStorageSenseGlobal' -Value 0 -Force
        Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Set AllowStorageSenseGlobal to 0", (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    catch {
        Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Failed to set AllowStorageSenseGlobal to 0", (Get-Date).ToUniversalTime()) -severity 'ERROR'
    }

    try {
        New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\StorageSense' -Name 'AllowStorageSenseTemporaryFilesCleanup' -Value 0 -Force
        Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Set AllowStorageSenseTemporaryFilesCleanup to 0", (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    catch {
        Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Failed to set AllowStorageSenseTemporaryFilesCleanup to 0", (Get-Date).ToUniversalTime()) -severity 'ERROR'
    }
}

# From time to time we need to have the different releases of the same OS version
$release_key = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion')
$release_id = $release_key.ReleaseId
$currentuser = whoami.exe

# OS caption
# Used to determine which KMS license for cloud workers
$caption = ((Get-WmiObject Win32_OperatingSystem).caption)
$caption = $caption.ToLower()
$os_caption = $caption -replace ' ', '_'
$base_image = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name "role"

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
Write-Log -Message ("{0} :: Executing task-user-init as $currentuser - {1:o}" -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'

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
        ## Taken from at_task_user_logon, except this code runs as task_xxxx and not as system
        while ($true) {
            $explorer = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -ErrorAction SilentlyContinue
            if ($null -eq $explorer) {
                Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Explorer not available inside task-user-init.ps1", (Get-Date).ToUniversalTime()) -severity 'DEBUG'
                Start-Sleep -Seconds 3
            }
            else {
                ## Tested against windows 11
                cmd.exe /c 'netsh firewall set notifications mode = disable profile = all'
                break
            }
        }

        ## set git config
        git config --global core.longpaths true
        git config --global --add safe.directory '*'
        explorer.exe shell::: { 3080F90D-D7AD-11D9-BD98-0000947B0257 } -Verb MinimizeAll
        Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Setting scrollbars to always show in task-user-init.ps1", (Get-Date).ToUniversalTime()) -severity 'DEBUG'
        New-ItemProperty -Path 'HKCU:\Control Panel\Accessibility' -Name 'DynamicScrollbars' -Value 0 -Force
        ## OneDriveSetup keeps causing issues, so disable it here
        ## https://bugzilla.mozilla.org/show_bug.cgi?id=1913499
        Disable-OneDrive
        ## Disable Storage Sense
        ## https://bugzilla.mozilla.org/show_bug.cgi?id=1893092#c140 localappdata gets cleaned up
        ## https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-storage
        Disable-StorageSense
    }
    "win_10_2009" {
        ## Taken from at_task_user_logon, except this code runs as task_xxxx and not as system
        while ($true) {
            $explorer = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -ErrorAction SilentlyContinue
            if ($null -eq $explorer) {
                Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Explorer not available inside task-user-init.ps1", (Get-Date).ToUniversalTime()) -severity 'DEBUG'
                Start-Sleep -Seconds 3
            }
            else {
                ## Tested against windows 11
                cmd.exe /c 'netsh firewall set notifications mode = disable profile = all'
                break
            }
        }

        ## set git config
        git config --global core.longpaths true
        git config --global --add safe.directory '*'
        explorer.exe shell::: { 3080F90D-D7AD-11D9-BD98-0000947B0257 } -Verb MinimizeAll
        Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Setting scrollbars to always show in task-user-init.ps1", (Get-Date).ToUniversalTime()) -severity 'DEBUG'
        New-ItemProperty -Path 'HKCU:\Control Panel\Accessibility' -Name 'DynamicScrollbars' -Value 0 -Force
        ## OneDriveSetup keeps causing issues, so disable it here
        ## https://bugzilla.mozilla.org/show_bug.cgi?id=1913499
        Disable-OneDrive
    }
    Default {}
}

## TODO: Figure out a way to install binaries/files as taskuser without defaulting to task-user-init
## do stuff based on the role
switch ($base_image) {
    "win11642009hwref" {
        ## Install appx package for av1 extension
        try {
            Write-Log -Message ('{0} :: Installing av1 extension' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Add-AppxPackage -Path "$env:systemdrive\RelSRE\Microsoft.AV1VideoExtension_1.1.62361.0_neutral_~_8wekyb3d8bbwe.AppxBundle" -ErrorAction "Stop"
            Write-Log -Message ('{0} :: Installed av1 extension' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        }
        catch {
            Write-Log -Message ('{0} :: Could not install av1 extension' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Write-Log -Message ('{0} :: Error: {1}' -f $($MyInvocation.MyCommand.Name), $_) -severity 'DEBUG'
        } 
    }
    "win11642009hwrefalpha" {
        ## Install appx package for av1 extension
        try {
            Write-Log -Message ('{0} :: Installing av1 extension' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Add-AppxPackage -Path "$env:systemdrive\RelSRE\Microsoft.AV1VideoExtension_1.1.62361.0_neutral_~_8wekyb3d8bbwe.AppxBundle" -ErrorAction "Stop"
            Write-Log -Message ('{0} :: Installed av1 extension' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        }
        catch {
            Write-Log -Message ('{0} :: Could not install av1 extension' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Write-Log -Message ('{0} :: Error: {1}' -f $($MyInvocation.MyCommand.Name), $_) -severity 'DEBUG'
        } 
    }
    default {
        continue
    }
}