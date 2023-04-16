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
$currentuser = whoami.exe

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
            git config --global core.longpaths true
            git config --global --add safe.directory '*'
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

        ## Test for the value set in at_task_user_logon.ps1 step
        Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Checking if scrollbar was set in at_task_user_logon.ps1", (Get-Date).ToUniversalTime()) -severity 'DEBUG'

        $d = Get-ItemPropertyValue -Path 'HKCU:\Control Panel\Accessibility' -Name 'DynamicScrollbars' #-Value 0
        if ($d -ne 0) {
            Write-Log -Message ('{0} :: {1} - {2:o}' -f $($MyInvocation.MyCommand.Name), "Setting scrollbars to always show in task-user-init.ps1", (Get-Date).ToUniversalTime()) -severity 'DEBUG'
            New-ItemProperty -Path 'HKCU:\Control Panel\Accessibility' -Name 'DynamicScrollbars' -Value 0
        }
    }
    "win_2012" {
        ## prevent Git repos from being seen as unsafe after copied
        git config --global --add safe.directory '*'
    }
    Default {}
}
