Function Set-ItelReg
{

$key0 = "hklm:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
$IDcheck0 = (Get-ItemProperty -Path $key0 -Name ProviderName).ProviderName
$key1 = "hklm:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0001"
$IDcheck1 = (Get-ItemProperty -Path $key1 -Name ProviderName).ProviderName



If ($IDcheck0 -eq "Intel Corporation") {
$IntelID = "0000"
$MSadpatID = "0001"
} Elseif ( $IDcheck1 -eq "Intel Corporation") {
$IntelID = "0001"
$MSadpatID = "0000"
} Else {

New-EventLog -LogName Application -Source "maintainsystem"
Write-Eventlog -LogName "Application" -Source "maintainsystem" -EventID 999  -EntryType Error -Message "Failed to set Intel registry ID; Drivers may not be installed" -Category 1 -RawData 10,20
Write-Eventlog -LogName "Application" -Source "maintainsystem" -EventID 999  -EntryType Error -Message "Contents of 0 is $IDcheck0 " -Category 1 -RawData 10,20
Write-Eventlog -LogName "Application" -Source "maintainsystem" -EventID 999  -EntryType Error -Message "Contents of 1 is $IDcheck1 " -Category 1 -RawData 10,20
[Environment]::Exit(1)
}

reg ADD "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\$IntelID" /v ForceVirtualDisplay /t REG_DWORD  /d 1 /f
reg ADD "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\$IntelID" /v Display_EnableSF /t REG_DWORD  /d 1 /f
reg ADD "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\$IntelID" /v EnableFakeCRT /t REG_DWORD  /d 1 /f
reg ADD "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\$IntelID" /v EnableFakeTV /t REG_DWORD  /d 1 /f
reg ADD "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\$IntelID" /v ReadEDIDFromRegistry /t REG_DWORD  /d 1 /f
reg ADD "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\$IntelID" /v Display1_EnableCRTHotPlugDefaultVrefVoltage /t REG_DWORD  /d 1 /f
reg ADD "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\$IntelID" /v InfPath /t REG_SZ /d oem5.inf /f
reg DELETE "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\$MSadpatID" /f

$adapter = Get-PnpDevice -Class Display | Where-Object { $_.Name -like "*Microsoft Basic Display Adapter*" }

if ($adapter) {
    Disable-PnpDevice -InstanceId $adapter.InstanceId -Confirm:$false
} else {
    exit 90
}
