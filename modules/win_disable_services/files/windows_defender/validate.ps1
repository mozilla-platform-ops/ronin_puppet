################################################################################
##  File:  Configure-WindowsDefender.ps1
##  Desc:  Disables Windows Defender
################################################################################

$exclusion = Get-MpPreference

if ($exclusion.DisableRealtimeMonitoring -ne $true) {
    Write-Host "Windows Defender is not disabled, disabling.."
    exit 1
}
else {
    Write-Host "Windows Defender is already disabled"
    exit 0
}
