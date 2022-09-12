Function Start-Restore {
    param (
        [string] $ronin_key = "HKLM:\SOFTWARE\Mozilla\ronin_puppet",
        [int32] $boots = (Get-ItemProperty $ronin_key).reboot_count,
        [int32] $max_boots = (Get-ItemProperty $ronin_key).max_boots,
        [string] $restore_needed = (Get-ItemProperty $ronin_key).restore_needed,
        [string] $checkpoint_date = (Get-ItemProperty $ronin_key).last_restore_point
  
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        if (($boots -ge $max_boots) -or ($restore_needed -notlike "false")) {
            if ($boots -ge $max_boots) {
                Write-Log -message  ('{0} :: System has reach the maxium number of reboots set at HKLM:\SOFTWARE\Mozilla\ronin_puppet\source\max_boots. Attempting restore.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            }
            if ($restore_needed -eq "gw_bad_config") {
                Write-Log -message  ('{0} :: Generic_worker has faild to start multiple times. Attempting restore.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            }
            if ($restore_needed -eq "puppetize_failed") {
                Write-Log -message  ('{0} :: Node has failed to Puppetize multiple times. Attempting restore .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            }
            if ($restore_needed -eq "force_restore") {
                Write-Log -message  ('{0} :: Restore requested by audit scripts. Attempting restore .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            }
            else {
                Write-Log -message  ('{0} :: Restore attempted for unknown reason. Restore key equals {1} .' -f $($MyInvocation.MyCommand.Name), ($restore_needed )) -severity 'DEBUG'
  
            }
            Stop-ScheduledTask -TaskName maintain_system
  
            Write-Log -message  ('{0} :: Removing Generic-worker directory .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Stop-process -name generic-worker -force
            Remove-Item -Recurse -Force $env:systemdrive\generic-worker
            Remove-Item -Recurse -Force $env:systemdrive\mozilla-build
            Remove-Item -Recurse -Force $env:ALLUSERSPROFILE\puppetlabs\ronin
            Remove-Item –Path -Force $env:windir\temp\*
            sc delete "generic-worker"
            Remove-ItemProperty -path $ronin_key -recurse -force
            # OpenSSH will need to be addressed it fails after restore
            # For now commented out of the roles manifests
            # sc delete sshd
            # sc delete ssh-agent
            # Remove-Item -Recurse -Force $env:ALLUSERSPROFILE\ssh
            Write-Log -message  ('{0} :: Initiating system restore from {1}.' -f $($MyInvocation.MyCommand.Name), ($checkpoint_date)) -severity 'DEBUG'
            $RestoreNumber = (Get-ComputerRestorePoint | Where-Object { $_.Description -eq "default" })
            Restore-Computer -RestorePoint $RestoreNumber.SequenceNumber
  
        }
        else {
            Write-Log -message  ('{0} :: Restore is not needed.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}
  