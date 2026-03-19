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
function Set-PXE {
    param (
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
		$temp_dir = "$env:systemdrive\temp\"
        New-Item -ItemType Directory -Force -Path $temp_dir -ErrorAction SilentlyContinue

		bcdedit /enum firmware > $temp_dir\firmware.txt

		$fwbootmgr = Select-String -Path "$temp_dir\firmware.txt" -Pattern "{fwbootmgr}"
		if (!$fwbootmgr){
			Write-Log -message  ('{0} :: Device is configured for Legacy Boot. Exiting!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
			Exit 999
		}
		Try{
			# Get the line of text with the GUID for the PXE boot option.
			# IPV4 = most PXE boot options
			# EFI Network = Hyper-V PXE boot option
			$FullLine = (( Get-Content $temp_dir\firmware.txt | Select-String "IPV4|EFI Network" -Context 1 -ErrorAction Stop ).context.precontext)[0]

			# Remove all text but the GUID
			$GUID = '{' + $FullLine.split('{')[1]

			# Add the PXE boot option to the top of the boot order on next boot
			bcdedit /set "{fwbootmgr}" bootsequence "$GUID"

			Write-Log -message  ('{0} :: Device will PXE boot. Restarting' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Start-Process -FilePath "shutdown.exe" -ArgumentList "/r /t 5 /f"
            return "success"
            exit 66
		}
		Catch {
			Write-Log -message  ('{0} :: Unable to set next boot to PXE. Exiting!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
			Exit 888
		}
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

Set-PXE
exit
