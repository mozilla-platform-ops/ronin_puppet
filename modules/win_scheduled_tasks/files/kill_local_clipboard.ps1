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

# logging below can be removed once thsi is working smoothly
while($true) {

	$clip_service = (Get-Service | Where-Object {$_.name -Like "cbdhsvc_*"})
	if ($clip_service.status -eq $null){
		Write-Log -message  ('{0} :: Local Clip Board service not detected' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
	} else {
		$start_type = ((Get-Service $clip_service.name).StartType)
		 Write-Log -message  ('{0} ::  {1} service is {2} and start up is set to {3}' -f $($MyInvocation.MyCommand.Name), ($clip_service), ($clip_service.status), ($start_type)) -severity 'DEBUG'
	}
	if ($clip_service.status -eq "running"){
		Write-Log -message  ('{0} ::  Stopping {1} service' -f $($MyInvocation.MyCommand.Name), ($clip_service)) -severity 'DEBUG'
		Stop-Service -Name $clip_service.name
		start-sleep -s 3
		Set-Service -name $clip_service.name -StartupType Disabled -force
	}
	start-sleep -s 5
	write-host waiting
}
