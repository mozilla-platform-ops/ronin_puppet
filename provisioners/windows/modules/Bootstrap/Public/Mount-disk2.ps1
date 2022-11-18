function Mount-DiskTwo {
    # Starting with disk 2 for now
    # Azure packer images does have a disk 1 labled ad temp storage
    # Maybe use that in the future
    param (
        [string] $lock = 'C:\dsc\in-progress.lock'
    )
    begin {
        Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
        if ((Test-VolumeExists -DriveLetter 'Y') -and (Test-VolumeExists -DriveLetter 'Z')) {
            Write-Log -message ('{0} :: skipping disk mount (drives y: and z: already exist).' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
        }
        else {
            $pagefileName = $false
            Get-WmiObject Win32_PagefileSetting | ? { !$_.Name.StartsWith('c:') } | % {
                $pagefileName = $_.Name
                try {
                    $_.Delete()
                    Write-Log -message ('{0} :: page file: {1}, deleted.' -f $($MyInvocation.MyCommand.Name), $pagefileName) -severity 'INFO'
                }
                catch {
                    Write-Log -message ('{0} :: failed to delete page file: {1}. {2}' -f $($MyInvocation.MyCommand.Name), $pagefileName, $_.Exception.Message) -severity 'ERROR'
                }
            }
            if (Get-Command -Name 'Clear-Disk' -errorAction SilentlyContinue) {
                try {
                    Clear-Disk -Number 2 -RemoveData -Confirm:$false
                    Write-Log -message ('{0} :: disk 1 partition table cleared.' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
                }
                catch {
                    Write-Log -message ('{0} :: failed to clear partition table on disk 1. {1}' -f $($MyInvocation.MyCommand.Name), $_.Exception.Message) -severity 'ERROR'
                }
            }
            else {
                Write-Log -message ('{0} :: partition table clearing skipped on unsupported os' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            }
            if (Get-Command -Name 'Initialize-Disk' -errorAction SilentlyContinue) {
                try {
                    Initialize-Disk -Number 2 -PartitionStyle MBR
                    Write-Log -message ('{0} :: disk 1 initialized.' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
                }
                catch {
                    Write-Log -message ('{0} :: failed to initialize disk 1. {1}' -f $($MyInvocation.MyCommand.Name), $_.Exception.Message) -severity 'ERROR'
                }
            }
            else {
                Write-Log -message ('{0} :: disk initialisation skipped on unsupported os' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            }
            if (Get-Command -Name 'New-Partition' -errorAction SilentlyContinue) {
                try {
                    New-Partition -DiskNumber 2 -Size 20GB -DriveLetter Y
                    Format-Volume -FileSystem NTFS -NewFileSystemLabel cache -DriveLetter Y -Confirm:$false
                    Write-Log -message ('{0} :: cache drive Y: formatted.' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
                }
                catch {
                    Write-Log -message ('{0} :: failed to format cache drive Y:. {1}' -f $($MyInvocation.MyCommand.Name), $_.Exception.Message) -severity 'ERROR'
                }
                try {
                    New-Partition -DiskNumber 2 -UseMaximumSize -DriveLetter Z
                    Format-Volume -FileSystem NTFS -NewFileSystemLabel task -DriveLetter Z -Confirm:$false
                    Write-Log -message ('{0} :: task drive Z: formatted.' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
                }
                catch {
                    Write-Log -message ('{0} :: failed to format task drive Z:. {1}' -f $($MyInvocation.MyCommand.Name), $_.Exception.Message) -severity 'ERROR'
                }
            }
            else {
                Write-Log -message ('{0} :: partitioning skipped on unsupported os' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            }
        }
    }
}
