$OldEAP = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

## Disable wuauserv
$servicesToDisable = @(
    'wuauserv',
    'usosvc',
    'uhssvc',
    'WaaSMedicSvc',
    'DoSvc'
) | Get-Service -ErrorAction SilentlyContinue

# Disable every update service before a stop can delay the boot task.
$servicesToDisable | Set-Service -StartupType Disabled
foreach ($s in $servicesToDisable) {
    if ($s.Status -ne "Stopped") {
        Stop-Service $s -Force
        $s.WaitForStatus('Stopped', "00:02:00")
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
