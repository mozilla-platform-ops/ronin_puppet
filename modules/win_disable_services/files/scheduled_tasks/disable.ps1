$SchTasksList = @(
    "AnalyzeSystem",
    "Cellular",
    "Consolidator",
    "Diagnostics",
    "FamilySafetyMonitor",
    "FamilySafetyRefreshTask",
    "MapsToastTask",
    "Microsoft Compatibility Appraiser",
    "Microsoft Compatibility Appraiser Exp",
    "Microsoft-Windows-DiskDiagnosticDataCollector",
    "NotificationTask",
    "ProcessMemoryDiagnosticEvents",
    "Proxy",
    "QueueReporting",
    "RecommendedTroubleshootingScanner",
    "RegIdleBackup",
    "RunFullMemoryDiagnostic",
    "ScheduledDefrag",
    "SpeechModelDownloadTask",
    "Sqm-Tasks",
    "SR",
    "StartComponentCleanup",
    "WindowsActionDialog",
    "WinSAT",
    "XblGameSaveTask",
    "UsbCeip",
    "VerifyWinRE",
    "Work Folders Logon Synchronization",
    "Work Folders Maintenance Work",
    "Restore"
)

Foreach ($Item in $SchTasksList) {
    $TaskObject = Get-ScheduledTask $Item -ErrorAction SilentlyContinue
    If ($TaskObject) {
        Disable-ScheduledTask -InputObject $TaskObject | Out-Null
    }
}