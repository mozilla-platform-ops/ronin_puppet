# Disable scheduled tasks
$allTasksInTaskPath = @(
    "\Microsoft\Windows\WindowsUpdate\"
)

$allTasksInTaskPath | ForEach-Object {
    Get-ScheduledTask -TaskPath $_ -ErrorAction Ignore | Disable-ScheduledTask -ErrorAction Ignore
} | Out-Null