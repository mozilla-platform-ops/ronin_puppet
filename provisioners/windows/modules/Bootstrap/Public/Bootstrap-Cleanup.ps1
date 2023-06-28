Function Bootstrap-CleanUp {
    param (
      [string] $bootstrapdir = "$env:systemdrive\BootStrap\"

    )
    begin {
      Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
      Write-Log -message  ('{0} :: Bootstrap has completed. Removing schedule task and directory' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
      Remove-Item -Recurse -Force $bootstrapdir
      Schtasks /delete /tn bootstrap /f

    }
    end {
      Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
  }
