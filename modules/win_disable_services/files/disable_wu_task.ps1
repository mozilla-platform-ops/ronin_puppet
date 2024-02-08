$OldEAP = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

## Disable wuauserv
$servicesToDisable = @(
    'wuauserv',
    'usosvc',
    'uhssvc',
    'WaaSMedicSvc'
) | Get-Service -ErrorAction SilentlyContinue

## Disable each service. Stop if they're still running
foreach ($s in $servicesToDisable) {
    if ($s.Status -ne "Stopped") {
        Stop-Service $s -Force
        $servicesToDisable.WaitForStatus('Stopped', "00:02:00")
        $servicesToDisable | Set-Service -StartupType Disabled
    }
    else {
        $s | Set-Service -StartupType Disabled
    }
}

## check if wuauserv is disabled, and if not, disable it again
if ((Get-Service "wuauserv").StartType -ne "Disabled") {
    if ((Get-Service "wuauserv").Status -ne "Stopped") {
        Stop-Service "wuauserv" -Force
    }
    Get-Service wuauserv | Set-Service -StartupType Disabled
}

# Disable scheduled tasks
$allTasksInTaskPath = @(
    "\Microsoft\Windows\InstallService\*",
    "\Microsoft\Windows\UpdateOrchestrator\*",
    "\Microsoft\Windows\UpdateAssistant\*",
    "\Microsoft\Windows\WaaSMedic\*",
    "\Microsoft\Windows\WindowsUpdate\*",
    "\Microsoft\WindowsUpdate\*"
)

$allTasksInTaskPath | ForEach-Object {
    Get-ScheduledTask -TaskPath $_ -ErrorAction Ignore | Disable-ScheduledTask -ErrorAction Ignore
} | Out-Null

$ErrorActionPreference = $OldEAP