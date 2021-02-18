<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>

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


Function Start-Restore {
  param (
    [string] $ronin_key = "HKLM:\SOFTWARE\Mozilla\ronin_puppet",
    [int32] $boots = (Get-ItemProperty $ronin_key).reboot_count,
    [int32] $max_boots = (Get-ItemProperty $ronin_key).max_boots,
    [string] $restore_needed = (Get-ItemProperty $ronin_key).restore_needed,
    [string] $checkpoint_date = (Get-ItemProperty $ronin_key).last_restore_point

  )
  begin {
  }
  process {

	Stop-ScheduledTask -TaskName maintain_system

	Write-Log -message  ('{0} :: Removing Generic-worker directory .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
	Stop-process -name generic-worker -force
	Remove-Item -Recurse -Force $env:systemdrive\generic-worker
	Remove-Item -Recurse -Force $env:systemdrive\mozilla-build
	Remove-Item -Recurse -Force $env:ALLUSERSPROFILE\puppetlabs\ronin
	Remove-Item –Path -Force $env:windir\temp\*
	sc delete "generic-worker"
	Write-Log -message  ('{0} :: Initiating system restore from {1}.' -f $($MyInvocation.MyCommand.Name), ($checkpoint_date)) -severity 'DEBUG'
	$RestoreNumber = (Get-ComputerRestorePoint | Where-Object {$_.Description -eq "default"})
	Restore-Computer -RestorePoint $RestoreNumber.SequenceNumber
  }
  end {
  }
}

Start-Restore
