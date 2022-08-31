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

# Commented out logs to reduce news but leaving in place if future debbugging is needed
while ($true) {
  ## add support for multiple services
  $clip_service = (Get-Service | Where-Object { $_.name -Like "cbdhsvc_*" })
  Foreach ($c in $clip_service) {
    if ($null -eq $c.Status) {
      Write-Log -message  ('{0} :: Local Clip Board service not detected' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    }
    else {
      $start_type = ((Get-Service $c.name).StartType)
      Write-Log -message  ('{0} :: {1} is {2} and start up is set to {3}' -f $($MyInvocation.MyCommand.Name), $c.DisplayName, ($c.status), ($start_type)) -severity 'DEBUG'
    }
    if ($c.status -eq "running") {
      Write-Log -message  ('{0} :: Stopping {1} service' -f $($MyInvocation.MyCommand.Name), $c.DisplayName) -severity 'DEBUG'
      Stop-Service -Name $c.name
      start-sleep -s 3
      Set-Service -name $c.name -StartupType Disabled -force
      ## Disable in the registry as Set-Service doesn't seem to disable per-user services
      start-sleep -s 5
      Write-Output "waiting"
    }
  }
}
