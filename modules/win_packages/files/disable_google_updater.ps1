$googleServices = Get-Service -Name "GoogleUpdater*"
if ( -Not [string]::IsNullOrEmpty($googleServices)) {
    Stop-Service $googleServices
    $googleServices.WaitForStatus('Stopped', "00:01:00")
    $googleServices | Set-Service -StartupType Disabled
}
