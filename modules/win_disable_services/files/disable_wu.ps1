## Disable wuauserv
$servicesToDisable = @(
    'wuauserv',
    'usosvc',
    'uhssvc',
    'WaaSMedicSvc'
) | Get-Service -ErrorAction SilentlyContinue

Stop-Service $servicesToDisable -Force
$servicesToDisable.WaitForStatus('Stopped', "00:02:00")
$servicesToDisable | Set-Service -StartupType Disabled

## check if wuauserv is disabled, and if not, disable it again
if ((Get-Service "wuauserv").StartType -ne "Disabled") {
    if ((Get-Service "wuauserv").Status -ne "Stopped") {
        Stop-Service "wuauserv" -Force
    }
    Get-Service wuauserv | Set-Service -StartupType Disabled
}