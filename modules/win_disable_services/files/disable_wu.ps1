## Disable wuauserv
$servicesToDisable = @(
    'wuauserv',
    'usosvc'
) | Get-Service -ErrorAction SilentlyContinue
Stop-Service $servicesToDisable
$servicesToDisable.WaitForStatus('Stopped', "00:01:00")
$servicesToDisable | Set-Service -StartupType Disabled