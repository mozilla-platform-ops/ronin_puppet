if (Get-Service -Name "wsearch" -ErrorAction SilentlyContinue) {
    $service = Get-Service "wsearch"
    if ($service.Status -ne "Stopped") {
        Stop-Service "wsearch" -Force
        $service.WaitForStatus('Stopped', "00:02:00")
        $service | Set-Service -StartupType Disabled

        takeown /f "C:\WINDOWS\system32\SearchIndexer.exe" /a
        icacls "C:\WINDOWS\system32\SearchIndexer.exe" /grant "Administrators:F"
        Rename-Item -Path "C:\WINDOWS\system32\SearchIndexer.exe" "C:\WINDOWS\system32\SearchIndexer.exe.bak"
    }
    else {
        takeown /f "C:\WINDOWS\system32\SearchIndexer.exe" /a
        icacls "C:\WINDOWS\system32\SearchIndexer.exe" /grant "Administrators:F"
        Rename-Item -Path "C:\WINDOWS\system32\SearchIndexer.exe" "C:\WINDOWS\system32\SearchIndexer.exe.bak"
    }

    $value = (Get-ItemProperty -Path "HKLM:\SYSTEM\ControlSet001\Services\WSearch").Start
    if ($value -ne 4) {
        Set-ItemProperty -Path "HKLM:\SYSTEM\ControlSet001\Services\WSearch" -Name Start -Value 4
    }
}
