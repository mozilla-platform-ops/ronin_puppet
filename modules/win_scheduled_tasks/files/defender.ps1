## Taken from https://wirediver.com/disable-windows-defender-in-powershell/

## Disable all paths and processes for defender 
## Did not work, excluding mozillabuild now
#67..90 | foreach-object {
#    $drive = [char]$_
#    Add-MpPreference -ExclusionPath "$($drive):\" -ErrorAction SilentlyContinue
#    Add-MpPreference -ExclusionProcess "$($drive):\*" -ErrorAction SilentlyContinue
#}

## Exclude mozilla build
Add-MpPreference -ExclusionPath "C:\mozilla-build" -ErrorAction SilentlyContinue

## Disable scanning engines
Set-MpPreference -DisableArchiveScanning $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableIntrusionPreventionSystem $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableRemovableDriveScanning $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableBlockAtFirstSeen $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableScanningMappedNetworkDrivesForFullScan $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableScanningNetworkFiles $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableScriptScanning $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue

Set-MpPreference -LowThreatDefaultAction Allow -ErrorAction SilentlyContinue
Set-MpPreference -ModerateThreatDefaultAction Allow -ErrorAction SilentlyContinue
Set-MpPreference -HighThreatDefaultAction Allow -ErrorAction SilentlyContinue

## Disable Services
$svc_list = @("WdNisSvc", "WinDefend", "Sense")
foreach ($svc in $svc_list) {
    if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc") {
        if ($(Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc").Start -ne 4) {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name Start -Value 4
        }
    }
    else {
        New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Force
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name Start -Value 4
    }
}

## Disable drivers
$drv_list = @("WdnisDrv", "wdfilter", "wdboot")
foreach ($drv in $drv_list) {
    if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\$drv") {
        if ($(Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$drv").Start -ne 4) {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$drv" -Name Start -Value 4
        }
    }
    else {
        New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Force
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name Start -Value 4
    }
}

## Disable registry items

# Cloud-delivered protection:
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection" -Name SpyNetReporting -Value 0
# Automatic Sample submission
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection" -Name SubmitSamplesConsent -Value 0
# Tamper protection
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" -Name TamperProtection -Value 4
# Disable in registry
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender" -Name DisableAntiSpyware -Value 1
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name DisableAntiSpyware -Value 1

## Delete windows defender (files, services, and drivers)
$pathsToDelete = @(
    "C:\ProgramData\Windows\Windows Defender Advanced Threat Protection\",
    "C:\ProgramData\Windows\Windows Defender\",
    "C:\Windows\System32\drivers\wd\"
    #"HKLM:\SYSTEM\CurrentControlSet\Services\WdNisSvc",
    #"HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend",
    #"HKLM:\SYSTEM\CurrentControlSet\Services\Sense",
    #"HKLM:\SYSTEM\CurrentControlSet\Services\WdnisDrv",
    #"HKLM:\SYSTEM\CurrentControlSet\Services\wdfilter",
    #"HKLM:\SYSTEM\CurrentControlSet\Services\wdboot"
)

$pathsToDelete | ForEach-Object {
    Remove-Item -Recurse -Force -Path $PSItem -ErrorAction SilentlyContinue -Confirm:$false
}

## End of https://wirediver.com/disable-windows-defender-in-powershell/

# $exclusion = Get-MpPreference

# if ($exclusion.DisableRealtimeMonitoring -ne $true) {
#     $avPreference = @(
#         @{DisableArchiveScanning = $true }
#         @{DisableAutoExclusions = $true }
#         @{DisableBehaviorMonitoring = $true }
#         @{DisableBlockAtFirstSeen = $true }
#         @{DisableCatchupFullScan = $true }
#         @{DisableCatchupQuickScan = $true }
#         @{DisableIntrusionPreventionSystem = $true }
#         @{DisableIOAVProtection = $true }
#         @{DisablePrivacyMode = $true }
#         @{DisableScanningNetworkFiles = $true }
#         @{DisableScriptScanning = $true }
#         @{MAPSReporting = 0 }
#         @{PUAProtection = 0 }
#         @{SignatureDisableUpdateOnStartupWithoutEngine = $true }
#         @{SubmitSamplesConsent = 2 }
#         @{ScanAvgCPULoadFactor = 5; ExclusionPath = @("D:\", "C:\", "Y:\", "Z:\") }
#         @{DisableRealtimeMonitoring = $true }
#     )
    
#     $avPreference += @(
#         @{EnableControlledFolderAccess = "Disable" }
#         @{EnableNetworkProtection = "Disabled" }
#     )
    
#     $avPreference | Foreach-Object {
#         $avParams = $_
#         Set-MpPreference @avParams
#     }
# }

# $defender_tasks = Get-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender\'
# if (-Not ([string]::IsNullOrEmpty($defender_tasks))) {
#     if ($defender_tasks.State -ne "Disabled") {
#         $defender_tasks | Disable-ScheduledTask | Out-Null
#     }
# }

# $atpRegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection'
# if ( -Not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection\ForceDefenderPassiveMode")) {
#     Set-ItemProperty -Path $atpRegPath -Name 'ForceDefenderPassiveMode' -Value '1' -Type 'DWORD' -Force
# }
