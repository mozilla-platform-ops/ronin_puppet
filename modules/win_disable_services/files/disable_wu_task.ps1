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