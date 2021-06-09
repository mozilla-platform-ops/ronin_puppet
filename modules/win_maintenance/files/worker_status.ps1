<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>

function Write-Log {
  param (
    [string] $message,
    [string] $severity = 'INFO',
    [string] $source = 'OpenCloudConfig',
    [string] $logName = 'Application'
  )
  if ((-not ([System.Diagnostics.EventLog]::Exists($logName))) -or (-not ([System.Diagnostics.EventLog]::SourceExists($source)))) {
    try {
      New-EventLog -LogName $logName -Source $source
    } catch {
      Write-Error -Exception $_.Exception -message ('failed to create event log source: {0}/{1}' -f $logName, $source)
    }
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
  try {
    Write-EventLog -LogName $logName -Source $source -EntryType $entryType -Category 0 -EventID $eventId -Message $message
  } catch {
    Write-Error -Exception $_.Exception -message ('failed to write to event log source: {0}/{1}. the log message was: {2}' -f $logName, $source, $message)
  }
  if ($env:OccConsoleOutput -eq 'host') {
    $fc = @{ 'Information' = 'White'; 'Error' = 'Red'; 'Warning' = 'DarkYellow'; 'SuccessAudit' = 'DarkGray' }[$entryType]
    Write-Host -object $message -ForegroundColor $fc
  } elseif ($env:OccConsoleOutput) {
    Write-Output -InputObject $message
  }
}

$production_worker_type=$args[0]
# works as hardcoded for now. SHould be a look up.
$domain = 'wintest.releng.mdc1.mozilla.com'
$current_worker_type = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").workerType
$gw_service = (Get-Service Generic*)
$wmi = (Get-WmiObject -Class win32_OperatingSystem)

if ($production_worker_type -ne $current_worker_type) {
	Write-Log -message  ('{0} :: AUDIT: Node is not in production. Currently configured to be a {1} worker.' -f $($MyInvocation.MyCommand.Name), ($current_worker_type)) -severity 'DEBUG'
	Write-host ('{0}.{1} is not in production. Currently configured to be {2} worker.' -f $($env:computername), ($domain), ($current_worker_type))
	exit 98
}

if (($wmi.ConvertToDateTime($wmi.LocalDateTime) - $wmi.ConvertToDateTime($wmi.LastBootUpTime)).Days -gt 2){
    Write-Log -message  ('{0} :: AUDIT: Worker has been up longer than a day.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    exit 99
}
if ($gw_service.status -ne "running") {
    Write-Log -message  ('{0} :: AUDIT: Generic worker service is not running.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    exit 99
} elseif ((get-process "generic-worker" -ea SilentlyContinue) -eq $Null) {
    Write-Log -message  ('{0} :: AUDIT: Generic worker process is not found.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    exit 99
} else {
	exit 0
}
