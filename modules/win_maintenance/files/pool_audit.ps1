param (
    [string] $git_hash,
    [string] $worker_pool_id
)

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
        Write-Host -Object $message -ForegroundColor $fc
    }
}

function Set-PXE {
    param ()
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        $temp_dir = "$env:systemdrive\temp\"
        New-Item -ItemType Directory -Force -Path $temp_dir -ErrorAction SilentlyContinue | Out-Null

        bcdedit /enum firmware > $temp_dir\firmware.txt

        $fwbootmgr = Select-String -Path "$temp_dir\firmware.txt" -Pattern "{fwbootmgr}"
        if (!$fwbootmgr) {
            Write-Log -message ('{0} :: Device is configured for Legacy Boot. Exiting!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            retrun 999
            Exit 999
        }
        Try {
            $FullLine = ((Get-Content $temp_dir\firmware.txt | Select-String "IPV4|EFI Network" -Context 1 -ErrorAction Stop).context.precontext)[0]
            $GUID = '{' + $FullLine.split('{')[1]
            bcdedit /set "{fwbootmgr}" bootsequence "$GUID"
            Write-Log -message ('{0} :: Device will PXE boot. Restarting' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Start-Process -FilePath "shutdown.exe" -ArgumentList "/r /t 5 /f"
            return "bad"
            exit 66
        }
        Catch {
            Write-Log -message ('{0} :: Unable to set next boot to PXE. Exiting!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            retrun 888
            Exit 888
        }
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

$hash = (Get-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet).GITHASH
$workerpool = (Get-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet).worker_pool_id

If ($git_hash -ne $hash) {
    Write-Log -message ('{0} :: Git hash mismatch. Beginning PXE boot process!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Write-Output "Git hash mismatch. Beginning PXE boot process!"
    Set-PXE
} elseif ($worker_pool_id -ne $workerpool) {
    Write-Log -message ('{0} :: Wrong worker pool. Beginning PXE boot process!' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    Write-Output "Wrong worker pool. Beginning PXE boot process!"
    Set-PXE
} else {
    Write-Output "No Issues"
    return "good"
}

exit
