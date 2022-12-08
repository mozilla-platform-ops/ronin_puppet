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

## For now, run all of the commands below on win10 or win11

## Disable windows security and maintenance notifications
$Path1 = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance'
if (-not (Test-Path $Path1)) {
    New-Item -Path $path1 -Force
}
Set-ItemProperty -Path $Path1 -Name Enabled -Value 0

## Set Windows VisualFX

<#
## Doesn't work https://www.reddit.com/r/PowerShell/comments/u3y4xd/change_visualfx_on_windows_11/
## Stackoverflow: https://stackoverflow.com/questions/9897310/can-you-change-the-visual-effects-performance-settings-from-an-application
## https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-systemparametersinfow
#>

## Enable Scrollbars to always show
if ($Null -eq (Get-ItemProperty -Path 'HKCU:\Control Panel\Accessibility').DynamicScrollbars) {
    New-ItemProperty -Path 'HKCU:\Control Panel\Accessibility' -Name 'DynamicScrollbars' -Value 0
}

## Prepare Chrome Profile
## Not needed due to only being required for hardware gpu testers
if (test-path "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe") {
    Start-Process chrome
    Start-Sleep -s 30
    taskkill /F /IM chrome.exe /T
}

## After all hkcu items are changed, restart explorer
Stop-Process -f -ProcessName explorer

# To-do: Add support for additional OS'
<#
switch ($os_caption) {
    "win_11_2009" {}
    "win_10_2004" {  }
    "win_2012" {
        $user = ((Get-WMIObject -ClassName Win32_ComputerSystem).Username)
        $task_user = $user.split('\')[1]
        $git_repo = ("Z:/{0}/*" -f ($task_user))
        git config --global --add safe.directory $git_repo
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    Default {}
}
#>
