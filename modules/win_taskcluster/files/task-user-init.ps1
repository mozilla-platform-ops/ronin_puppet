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

function Set-WindowState {
    <#
    .SYNOPSIS
    Set the state of a window.

    .DESCRIPTION
    Set the state of a window using the `ShowWindowAsync` function from `user32.dll`.

    .PARAMETER InputObject
    The process object(s) to set the state of. Can be piped from `Get-Process`.

    .PARAMETER State
    The state to set the window to. Default is 'SHOW'.

    .PARAMETER SuppressErrors
    Suppress errors when the main window handle is '0'.

    .PARAMETER SetForegroundWindow
    Set the window to the foreground

    .PARAMETER ThresholdHours
    The number of hours to keep the window handle in memory. Default is 24.

    .EXAMPLE
    Get-Process notepad | Set-WindowState -State HIDE -SuppressErrors

    .EXAMPLE
    Get-Process notepad | Set-WindowState -State SHOW -SuppressErrors

    .LINK
    https://gist.github.com/lalibi/3762289efc5805f8cfcf

    .NOTES
    Original idea from https://gist.github.com/Nora-Ballard/11240204
    #>

    [CmdletBinding(DefaultParameterSetName = 'InputObject')]
    param(
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [Object[]] $InputObject,

        [Parameter(Position = 1)]
        [ValidateSet(
            'FORCEMINIMIZE', 'HIDE', 'MAXIMIZE', 'MINIMIZE', 'RESTORE',
            'SHOW', 'SHOWDEFAULT', 'SHOWMAXIMIZED', 'SHOWMINIMIZED',
            'SHOWMINNOACTIVE', 'SHOWNA', 'SHOWNOACTIVATE', 'SHOWNORMAL'
        )]
        [string] $State = 'SHOW',
        [switch] $SuppressErrors = $false,
        [switch] $SetForegroundWindow = $false,
        [int] $ThresholdHours = 24
    )

    Begin {
        $WindowStates = @{
            'FORCEMINIMIZE'   = 11
            'HIDE'            = 0
            'MAXIMIZE'        = 3
            'MINIMIZE'        = 6
            'RESTORE'         = 9
            'SHOW'            = 5
            'SHOWDEFAULT'     = 10
            'SHOWMAXIMIZED'   = 3
            'SHOWMINIMIZED'   = 2
            'SHOWMINNOACTIVE' = 7
            'SHOWNA'          = 8
            'SHOWNOACTIVATE'  = 4
            'SHOWNORMAL'      = 1
        }

        $Win32ShowWindowAsync = Add-Type -MemberDefinition @'
[DllImport("user32.dll")]
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll", SetLastError = true)]
public static extern bool SetForegroundWindow(IntPtr hWnd);
'@ -Name "Win32ShowWindowAsync" -Namespace Win32Functions -PassThru

        $global:MainWindowHandles = @{}

    }

    Process {
        foreach ($process in $InputObject) {
            $handle = $process.MainWindowHandle

            if ($handle -eq 0 -and $global:MainWindowHandles.ContainsKey($process.Id)) {
                $handle = [int] $global:MainWindowHandles[$process.Id].Handle
            }

            if ($handle -eq 0) {
                if (-not $SuppressErrors) {
                    Write-Error "Main Window handle is '0'"
                }
                else {
                    Write-Verbose ("Skipping '{0}' with id '{1}', because Main Window handle is '0'" -f $process.ProcessName, $process.Id)
                }

                continue
            }

            Write-Verbose ("Processing '{0}' with id '{1}' and handle '{2}'" -f $process.ProcessName, $process.Id, $handle)

            $global:MainWindowHandles[$process.Id] = @{
                Handle    = $handle.ToString()
                Timestamp = (Get-Date).ToString("o")
            }

            $Win32ShowWindowAsync::ShowWindowAsync($handle, $WindowStates[$State]) | Out-Null

            if ($SetForegroundWindow) {
                $Win32ShowWindowAsync::SetForegroundWindow($handle) | Out-Null
            }

            Write-Verbose ("» Set Window State '{1}' on '{0}'" -f $handle, $State)
        }
    }

    End {
        $data = [ordered] @{}

        foreach ($key in $global:MainWindowHandles.Keys) {
            if ($global:MainWindowHandles[$key].Handle -ne 0) {
                $data["$key"] = $global:MainWindowHandles[$key]
            }
        }
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

## Minimize the cmd.exe window that pops up when running a task
## Wait until the process with path C:\task_* is found, then hide cmd.exe
do {
    $taskProcess = Get-Process | Where-Object { $_.Path -like "C:\task_*" }
    if (-not $taskProcess) {
        Write-Log -Message ('{0} :: Waiting for process with path matching C:\task_*' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        Start-Sleep -Seconds 5
    }
} until ($taskProcess)

$cmdproc = Get-Process | Where-Object { $PSItem.Path -eq "C:\windows\System32\cmd.exe" }
if ($null -ne $cmdproc) {
    Write-Log -Message ('{0} :: Hiding cmd.exe window' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    $cmdproc | Set-WindowState -State HIDE
}
else {
    do {
        $cmdprocess = Get-Process | Where-Object { $PSItem.Path -eq "C:\windows\System32\cmd.exe" }
        if (-not $cmdprocess) {
            Write-Log -Message ('{0} :: Waiting for process of cmd.exe to hide' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Start-Sleep -Seconds 5
        }
    } until ($cmdprocess)
    Write-Log -Message ('{0} :: Hiding cmd.exe window' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    $cmdprocess | Set-WindowState -State HIDE
}
