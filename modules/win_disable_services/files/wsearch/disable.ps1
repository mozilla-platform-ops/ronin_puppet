$service = Get-Service "wsearch" -ErrorAction SilentlyContinue
if ($service -and $service.Status -ne "Stopped") {
    Stop-Service "wsearch" -Force
    $service.WaitForStatus('Stopped', "00:02:00")
}
if ($service) {
    $service | Set-Service -StartupType Disabled
}

# Idempotent: only take ownership and rename the indexer if it hasn't already been
# renamed. Without this guard the exec fails on every re-apply (SearchIndexer.exe is
# gone after the first run) — puppet re-applies on a schedule, and the bake may apply
# more than once.
$indexer = "C:\WINDOWS\system32\SearchIndexer.exe"
if (Test-Path $indexer) {
    takeown /f $indexer /a
    icacls $indexer /grant "Administrators:F"
    Rename-Item -Path $indexer "$indexer.bak"
}

$value = (Get-ItemProperty -Path "HKLM:\SYSTEM\ControlSet001\Services\WSearch").Start
if ($value -ne 4) {
    Set-ItemProperty -Path "HKLM:\SYSTEM\ControlSet001\Services\WSearch" -Name Start -Value 4
}
