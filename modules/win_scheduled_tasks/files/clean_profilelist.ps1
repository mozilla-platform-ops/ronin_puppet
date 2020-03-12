<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>


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
<#
$userProfiles = @(Get-ChildItem -path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList' | ? { $_.Name -match 'S-1-5-21-'})
Write-Log -message ('{0} :: {1} UserProfiles detected' -f $($MyInvocation.MyCommand.Name), $userProfiles.Length) -severity 'DEBUG'
foreach ($userProfile in $userProfiles) {
$sid = [System.Io.Path]::GetFileName($userProfile)
try {
	$user = (New-Object System.Security.Principal.SecurityIdentifier ($sid)).Translate([System.Security.Principal.NTAccount]).Value
	Write-Log -message ('{0} :: UserProfile: {1} - {2}' -f $($MyInvocation.MyCommand.Name), $user, $sid) -severity 'DEBUG'
	} catch {
	# the translate call in the try block above will fail if the user profile sid does not map to a user account.
	# if that is the case, we remove the sid from the registry profile list, in order to prevent the registry consuming too much disk space
	# for all the task user profiles created and deleted by the generic worker.
	$userProfile | Remove-Item -Force -Confirm:$false
	Write-Log -message ('{0} :: UserProfile sid: {1} failed to map to a user account and was removed' -f $($MyInvocation.MyCommand.Name), $sid) -severity 'DEBUG'
	}
}
#>
