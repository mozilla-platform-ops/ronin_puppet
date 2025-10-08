function Write-Log {
    param (
        [string] $message,
        [string] $severity = 'INFO',
        [string] $source = 'BootStrap',
        [string] $logName = 'Application'
    )
    if (!([Diagnostics.EventLog]::Exists($logName)) -or !([Diagnostics.EventLog]::SourceExists($source))) {
        New-EventLog -LogName $logName -Source $source
    }
    switch ($severity) {
        'DEBUG' {
            $entryType = 'SuccessAudit'
            $eventId = 2
            break
        }
        'WARN' {
            $entryType = 'Warning'
            $eventId = 3
            break
        }
        'ERROR' {
            $entryType = 'Error'
            $eventId = 4
            break
        }
        default {
            $entryType = 'Information'
            $eventId = 1
            break
        }
    }
    Write-EventLog -LogName $logName -Source $source -EntryType $entryType -Category 0 -EventID $eventId -Message $message
    if ([Environment]::UserInteractive) {
        $fc = @{ 'Information' = 'White'; 'Error' = 'Red'; 'Warning' = 'DarkYellow'; 'SuccessAudit' = 'DarkGray' }[$entryType]
        Write-Host  -object $message -ForegroundColor $fc
    }
}

Foreach ($Item in @("SilentCleanup","StartComponentCleanup")) {
    $TaskObject = Get-ScheduledTask $Item -ErrorAction SilentlyContinue
    If ($TaskObject) {
        Write-Log -Message ("{0} :: Disabling Scheduled Task: {1}" -f $($MyInvocation.MyCommand.Name), $TaskObject.TaskName) -severity 'DEBUG'
        Disable-ScheduledTask -InputObject $TaskObject | Out-Null
    }
}

## Microsoft has a space in account cleanup scheduled task
$Acc_TaskObject = Get-ScheduledTask "Account Cleanup" -ErrorAction SilentlyContinue
If ($Acc_TaskObject) {
    Write-Log -Message ("{0} :: Disabling Scheduled Task: {1}" -f $($MyInvocation.MyCommand.Name), $Acc_TaskObject.TaskName) -severity 'DEBUG'
    Disable-ScheduledTask -InputObject $Acc_TaskObject | Out-Null
}