Function Bootstrap-schtasks {
    param (
        [string] $image_provisioner,
        [string] $workerType,
        [string] $src_Organisation,
        [string] $src_Repository,
        [string] $src_Revision
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
  
        # This will not really do anything for the Azure script but shouldn't hurt it
        # It is needed for hardware workers
        $role = $workerType -replace '-', ''
  
        Set-ExecutionPolicy unrestricted -force  -ErrorAction SilentlyContinue
        Invoke-WebRequest https://raw.githubusercontent.com/$src_Organisation/$src_Repository/$src_Revision/provisioners/windows/$image_provisioner/$role-bootstrap.ps1 -OutFile "$env:systemdrive\BootStrap\$role-bootstrap-src.ps1" -UseBasicParsing
        Get-Content -Encoding UTF8 $env:systemdrive\BootStrap\$role-bootstrap-src.ps1 | Out-File -Encoding Unicode $env:systemdrive\BootStrap\$role-bootstrap.ps1
        Schtasks /create /RU system /tn bootstrap /tr "powershell -file $env:systemdrive\BootStrap\$role-bootstrap.ps1" /sc onstart /RL HIGHEST /f
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}
  