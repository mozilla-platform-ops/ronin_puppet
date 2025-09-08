<# 
Disables OneDrive setup/integration pre-sysprep.
Run elevated as SYSTEM in Audit Mode on the reference image (Windows 10/11 x64).
#>

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "== Kill OneDrive/Explorer =="
Stop-Process -Name OneDrive -Force
Stop-Process -Name OneDriveSetup -Force
Stop-Process -Name explorer -Force

Write-Host "== Correct GPO-backed policy =="
$pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive'
New-Item -Path $pol -Force | Out-Null
New-ItemProperty -Path $pol -Name 'DisableFileSyncNGSC' -PropertyType DWord -Value 1 -Force | Out-Null
# Clean incorrect Wow6432Node path (if previously set)
Remove-Item -Path 'HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\OneDrive' -Recurse -Force

Write-Host "== Default profile: remove first-run hooks for new users =="
$defaultHive = 'HKU\Default'
$defaultNtUsr = 'C:\Users\Default\NTUSER.DAT'
if (Test-Path $defaultNtUsr) {
    reg load $defaultHive $defaultNtUsr | Out-Null

    # Known values
    reg delete "$defaultHive\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f | Out-Null
    reg delete "$defaultHive\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "OneDrive" /f | Out-Null

    # Remove any other values that point to OneDriveSetup.exe
    foreach ($rk in @(
            "Registry::$defaultHive\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
            "Registry::$defaultHive\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
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

    reg unload $defaultHive | Out-Null
}
else {
    Write-Warning "Default profile hive not found at $defaultNtUsr"
}

Write-Host "== Machine-level Run/RunOnce cleanup =="
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

Write-Host "== Remove OneDrive scheduled tasks (root and \\Microsoft\\OneDrive) =="
Get-ScheduledTask -ErrorAction SilentlyContinue |
Where-Object { $_.TaskName -like 'OneDrive*' -or $_.TaskPath -like '\Microsoft\OneDrive\*' } |
Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "== Uninstall OneDrive binaries (both stubs) =="
$sys32 = "$env:WINDIR\System32\OneDriveSetup.exe"
$wow64 = "$env:WINDIR\SysWOW64\OneDriveSetup.exe"
if (Test-Path $sys32) { & $sys32 /uninstall }
if (Test-Path $wow64) { & $wow64 /uninstall }

Write-Host "== Remove OneDrive leftovers =="
Remove-Item -LiteralPath "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force
Remove-Item -LiteralPath "$env:PROGRAMDATA\Microsoft OneDrive" -Recurse -Force
Remove-Item -LiteralPath "$env:SYSTEMDRIVE\OneDriveTemp" -Recurse -Force
if (Test-Path "$env:USERPROFILE\OneDrive") {
    if ((Get-ChildItem "$env:USERPROFILE\OneDrive" -Recurse | Measure-Object).Count -eq 0) {
        Remove-Item -LiteralPath "$env:USERPROFILE\OneDrive" -Recurse -Force
    }
}

Write-Host "== Restart Explorer (optional) =="
Start-Process explorer.exe

Write-Host "Complete: OneDrive setup disabled for new users and existing machine context. Ready for Sysprep."
