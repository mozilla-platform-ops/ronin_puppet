function Write-Log {
  param (
    [string] $message,
    [string] $severity = 'INFO',
    [string] $source = 'MaintainSystem',
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
    Write-Host -object $message -ForegroundColor $fc
  }
}

$Monitors = ((Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams | where {$_.Active -like "True"}).Active.Count)

if ($Monitors -eq 2) {
	Write-Log -message ('{0} :: Two monitors detected. Disabling 2nd monitor' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
	C:\ControlMyMonitor\ControlMyMonitor.exe /SetValue "\\.\DISPLAY1\Monitor1" D6 5
	Start-Sleep -s 30
	$Monitors2 = ((Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams | where {$_.Active -like "True"}).Active.Count)
	if ($Monitors -eq 2) {
		Write-Log -message ('{0} :: Disabling 2nd monitor failed!!!' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
		exit 99
	}
} elseif ($Monitors -eq 1) {
	Write-Log -message ('{0} :: Single monitor detected. Nothing to do' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
	exit 0
} else {
	Write-Log -message ('{0} :: {1} monitors detected. Unexpected state. Exiting non-zero' -f $($MyInvocation.MyCommand.Name), $Monitors) -severity 'INFO'
	exit 98
}
