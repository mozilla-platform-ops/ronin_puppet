################################################################################
##  File:  Configure-WindowsDefender.ps1
##  Desc:  Disables Windows Defender
################################################################################

try {
    Write-Host "Disable Windows Defender..."
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
        @{ScanAvgCPULoadFactor = 5; ExclusionPath = @("D:\", "C:\") }
        @{DisableRealtimeMonitoring = $true }
        @{ScanScheduleDay = 8 }
        @{EnableControlledFolderAccess = "Disable" }
        @{EnableNetworkProtection = "Disabled" }
    )

    $avPreference | Foreach-Object {
        $avParams = $_
        ## Break out of try catch if there's an error
        Set-MpPreference @avParams -ErrorAction "Stop"
    }
    exit 0
}
catch {
    exit 1
}
