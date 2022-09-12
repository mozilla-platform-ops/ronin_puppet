function Set-PesterVersion {
    [CmdletBinding()]
    param (
      
    )
    
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    
    process {
        ## Bootstrap for powershell modules
        Get-PackageProvider -Name Nuget -ForceBootstrap | Out-Null
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
  
        ## Remove built-in version of pester
        $module = "C:\Program Files\WindowsPowerShell\Modules\Pester"
        takeown /F $module /A /R
        icacls $module /reset
        icacls $module /grant "*S-1-5-32-544:F" /inheritance:d /T
        Remove-Item -Path $module -Recurse -Force -Confirm:$false
  
        ## install Pester
        Install-Module -Name Pester -Force
    }
    
    end {
        Write-Log -message  ('{0} :: Pester 5 installation appears complete' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
    }
}