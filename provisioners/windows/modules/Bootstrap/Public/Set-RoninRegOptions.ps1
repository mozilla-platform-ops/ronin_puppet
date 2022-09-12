function Set-RoninRegOptions {
    param (
        [string] $mozilla_key = "HKLM:\SOFTWARE\Mozilla\",
        [string] $ronnin_key = "$mozilla_key\ronin_puppet",
        [string] $source_key = "$ronnin_key\source",
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
        If (!( test-path "$ronnin_key")) {
            New-Item -Path HKLM:\SOFTWARE -Name Mozilla –Force
            New-Item -Path HKLM:\SOFTWARE\Mozilla -name ronin_puppet –Force
        }
  
        New-Item -Path $ronnin_key -Name source –Force
        New-ItemProperty -Path "$ronnin_key" -Name 'image_provisioner' -Value "$image_provisioner" -PropertyType String
        New-ItemProperty -Path "$ronnin_key" -Name 'workerType' -Value "$workerType" -PropertyType String
        $role = $workerType -replace '-', ''
        New-ItemProperty -Path "$ronnin_key" -Name 'role' -Value "$role" -PropertyType String
        Write-Log -message  ('{0} :: Node workerType set to {1}' -f $($MyInvocation.MyCommand.Name), ($workerType)) -severity 'DEBUG'
  
        New-ItemProperty -Path "$ronnin_key" -Name 'inmutable' -Value 'false' -PropertyType String
        New-ItemProperty -Path "$ronnin_key" -Name 'runtosuccess' -Value 'true' -PropertyType String
        New-ItemProperty -Path "$ronnin_key" -Name 'last_run_exit' -Value '0' -PropertyType Dword
        New-ItemProperty -Path "$ronnin_key" -Name 'bootstrap_stage' -Value 'setup' -PropertyType String
  
  
        New-ItemProperty -Path "$source_key" -Name 'Organisation' -Value "$src_Organisation" -PropertyType String
        New-ItemProperty -Path "$source_key" -Name 'Repository' -Value "$src_Repository" -PropertyType String
        New-ItemProperty -Path "$source_key" -Name 'Revision' -Value "$src_Revision" -PropertyType String
  
    }
    end {
        Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}