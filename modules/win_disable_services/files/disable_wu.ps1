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