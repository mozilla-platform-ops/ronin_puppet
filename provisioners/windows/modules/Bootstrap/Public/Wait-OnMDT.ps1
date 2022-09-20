function Wait-OnMDT {
    [CmdletBinding()]
    param (
        
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        while ((Test-Path "$env:systemdrive:\MININT")) {
            Write-Log -message  ('{0} ::Detecting MDT deployment has not completed. Waiting 10 seconds.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Start-Sleep 10
        }
        Write-Log -message  ('{0} ::MDT deployment appears complete' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}
