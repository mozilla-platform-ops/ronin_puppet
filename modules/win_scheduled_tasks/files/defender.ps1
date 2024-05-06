$exclusion = Get-MpPreference

if ($exclusion.DisableRealtimeMonitoring -ne $true) {
    $avPreference = @(
        @{DisableArchiveScanning = $true }
        @{DisableAutoExclusions = $true }
        @{DisableBehaviorMonitoring = $true }
        @{DisableBlockAtFirstSeen = $true }
        @{DisableCatchupFullScan = $true }
        @{DisableCatchupQuickScan = $true }
        @{DisableIntrusionPreventionSystem = $true }
        @{DisableIOAVProtection = $true }
        @{DisablePrivacyMode = $true }
        @{DisableScanningNetworkFiles = $true }
        @{DisableScriptScanning = $true }
        @{MAPSReporting = 0 }
        @{PUAProtection = 0 }
        @{SignatureDisableUpdateOnStartupWithoutEngine = $true }
        @{SubmitSamplesConsent = 2 }
        @{ScanAvgCPULoadFactor = 5; ExclusionPath = @("D:\", "C:\", "Y:\", "Z:\") }
        @{DisableRealtimeMonitoring = $true }
    )
    
    $avPreference += @(
        @{EnableControlledFolderAccess = "Disable" }
        @{EnableNetworkProtection = "Disabled" }
    )
    
    $avPreference | Foreach-Object {
        $avParams = $_
        Set-MpPreference @avParams
    }
}

$defender_tasks = Get-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender\'
if (-Not ([string]::IsNullOrEmpty($defender_tasks))) {
    if ($defender_tasks.State -ne "Disabled") {
        $defender_tasks | Disable-ScheduledTask | Out-Null
    }
}

$atpRegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection'
if ( -Not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection\ForceDefenderPassiveMode")) {
    Set-ItemProperty -Path $atpRegPath -Name 'ForceDefenderPassiveMode' -Value '1' -Type 'DWORD' -Force
}
