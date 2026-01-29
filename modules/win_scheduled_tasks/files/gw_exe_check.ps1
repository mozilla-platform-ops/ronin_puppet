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
        'DEBUG' { $entryType = 'SuccessAudit'; $eventId = 2; break }
        'WARN'  { $entryType = 'Warning';      $eventId = 3; break }
        'ERROR' { $entryType = 'Error';        $eventId = 4; break }
        default { $entryType = 'Information'; $eventId = 1; break }
    }
    Write-EventLog -LogName $logName -Source $source -EntryType $entryType -Category 0 -EventID $eventId -Message $message
    if ([Environment]::UserInteractive) {
        $fc = @{ 'Information' = 'White'; 'Error' = 'Red'; 'Warning' = 'DarkYellow'; 'SuccessAudit' = 'DarkGray' }[$entryType]
        Write-Host -Object $message -ForegroundColor $fc
    }
}

function Set-PXE {
    param ()
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        $temp_dir = "$env:SystemDrive\temp\"
        New-Item -ItemType Directory -Force -Path $temp_dir -ErrorAction SilentlyContinue

        bcdedit /enum firmware > "$temp_dir\firmware.txt"

        $fwbootmgr = Select-String -Path "$temp_dir\firmware.txt" -Pattern "{fwbootmgr}"
        if (!$fwbootmgr) {
            Write-Log -message ('{0} :: Device is configured for Legacy Boot. Exiting!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Exit 999
        }
        Try {
            $FullLine = ((Get-Content "$temp_dir\firmware.txt" | Select-String "IPV4|EFI Network" -Context 1 -ErrorAction Stop).Context.PreContext)[0]
            $GUID = '{' + $FullLine.Split('{')[1]
            bcdedit /set "{fwbootmgr}" bootsequence "$GUID"

            Write-Log -message ('{0} :: Device will PXE boot. Restarting' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Restart-Computer -Force
            Exit
        }
        Catch {
            Write-Log -message ('{0} :: Unable to set next boot to PXE. Exiting!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Exit 888
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

# Main monitoring script

# Initial sleep for 10 minutes
Write-Log -message "Sleeping 10 minutes before starting GW monitoring..." -severity 'DEBUG'
Start-Sleep -Seconds (10 * 60)

$regPath = "HKLM:\SOFTWARE\Mozilla\Ronin"
$regName = "GW_failed"

while ($true) {
    Write-Log -message "Checking for 'generic-worker' process..." -severity 'DEBUG'

    $process = Get-Process -Name "generic-worker" -ErrorAction SilentlyContinue

    if (-not $process) {
        Write-Log -message "Generic Worker process not found." -severity 'WARN'

        if (!(Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }

        $currentValue = $null
        Try {
            $currentValue = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction Stop).$regName
        } Catch {
            # If the property does not exist, we'll treat it as first failure
            $currentValue = $null
        }

        if ($currentValue -eq 1) {
            Write-Log -message "Generic Worker still missing after previous failure. Initiating PXE boot..." -severity 'ERROR'
            Set-PXE
            # Set-PXE will reboot and exit
        } else {
            Write-Log -message "First failure detected. Setting GW_failed=1." -severity 'WARN'
            Set-ItemProperty -Path $regPath -Name $regName -Value 1 -Force
        }
    } else {
        Write-Log -message "Generic Worker process is running." -severity 'DEBUG'

        if (Test-Path $regPath) {
            $currentValue = $null
            Try {
                $currentValue = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction Stop).$regName
            } Catch {
                $currentValue = $null
            }

            if ($currentValue -eq 1) {
                Write-Log -message "Generic Worker recovered. Removing GW_failed flag." -severity 'DEBUG'
                Remove-ItemProperty -Path $regPath -Name $regName -Force
            }
        }
    }

    # Sleep 5 minutes before next check
    Write-Log -message "Sleeping 5 minutes until next check..." -severity 'DEBUG'
    Start-Sleep -Seconds (5 * 60)
}
