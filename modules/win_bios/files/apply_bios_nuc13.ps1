param (
    [string] $BiosCfg
)

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
        Write-Host -object $message -ForegroundColor $fc
    }
}

function Invoke-BiosApply {
    param (
        [string] $BiosCfg
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        $badText = 'Admin password does not exist'
        $timeoutSeconds = 60

        Write-Log -message ('{0} :: applying BIOS config {1}' -f $($MyInvocation.MyCommand.Name), $BiosCfg) -severity 'DEBUG'

        $job = Start-Job -ScriptBlock {
            param ($dir, $cfg)
            Set-Location $dir
            $out = & ".\iSetupCfgWin64.exe" /i /cpwd admin /s ".\$cfg" 2>&1
            [PSCustomObject]@{
                Output   = $out
                ExitCode = $LASTEXITCODE
            }
        } -ArgumentList $PSScriptRoot, $BiosCfg

        $completed = Wait-Job $job -Timeout $timeoutSeconds

        if (-not $completed) {
            Stop-Job $job -Force
            Remove-Job $job -Force
            Write-Log -message ('{0} :: timed out after {1} seconds' -f $($MyInvocation.MyCommand.Name), $timeoutSeconds) -severity 'ERROR'
            exit 1
        }

        $result = Receive-Job $job
        Remove-Job $job -Force

        $nativeExit = $result.ExitCode
        $output = $result.Output

        Write-Log -message ('{0} :: iSetupCfg output: {1}' -f $($MyInvocation.MyCommand.Name), ($output -join ' ')) -severity 'DEBUG'

        if ($output | Select-String -SimpleMatch $badText) {
            Write-Log -message ('{0} :: FAILED to apply BIOS settings' -f $($MyInvocation.MyCommand.Name)) -severity 'ERROR'
            Write-Log -message ('{0} :: iSetupCfg password needs to be set to bypass in BIOS' -f $($MyInvocation.MyCommand.Name)) -severity 'ERROR'
            exit 1
        }

        if ($nativeExit -ne 0) {
            Write-Log -message ('{0} :: FAILED to apply BIOS settings' -f $($MyInvocation.MyCommand.Name)) -severity 'ERROR'
            exit 1
        }

        Write-Log -message ('{0} :: BIOS config applied successfully' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}

Invoke-BiosApply -BiosCfg $BiosCfg
exit 0
