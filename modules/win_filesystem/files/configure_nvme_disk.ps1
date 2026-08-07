[CmdletBinding()]
param (
    [switch] $Required,
    [ValidateRange(0, 3600)]
    [int] $WaitSeconds = 0,
    [ValidateRange(1, 300)]
    [int] $RetrySeconds = 5
)

$ErrorActionPreference = 'Stop'

$driveLetter = 'D'
$poolName = 'NVMePool'
$virtualDiskName = 'NVMeTemporary'

function Get-ReadyTemporaryVolume {
    param (
        [string] $DriveLetter
    )

    Get-Volume -DriveLetter $DriveLetter -ErrorAction SilentlyContinue |
        Where-Object { $_.DriveType -eq 'Fixed' } |
        Select-Object -First 1
}

function Get-AzureNvmeDataDisks {
    @(
        Get-Disk -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FriendlyName -like '*NVMe Direct Disk*' -and
                -not $_.IsBoot -and
                -not $_.IsSystem -and
                $_.PartitionStyle -eq 'RAW'
            } |
            Sort-Object Number
    )
}

function Wait-AzureNvmeDataDisks {
    param (
        [int] $WaitSeconds,
        [int] $RetrySeconds
    )

    $retryCount = [Math]::Ceiling([double] $WaitSeconds / $RetrySeconds)

    for ($attempt = 0; $attempt -le $retryCount; $attempt++) {
        $disks = @(Get-AzureNvmeDataDisks)
        if ($disks.Count -gt 0) {
            return $disks
        }

        if ($attempt -lt $retryCount) {
            Start-Sleep -Seconds $RetrySeconds
        }
    }

    return @()
}

function Move-CdRomFromTemporaryDrive {
    param (
        [string] $DriveLetter
    )

    $currentDrive = ('{0}:' -f $DriveLetter)
    $cdRomDrive = Get-CimInstance -ClassName Win32_Volume -ErrorAction SilentlyContinue |
        Where-Object { $_.DriveLetter -eq $currentDrive -and $_.DriveType -eq 5 } |
        Select-Object -First 1

    if ($cdRomDrive) {
        Set-CimInstance -InputObject $cdRomDrive -Property @{ DriveLetter = 'Z:' } | Out-Null
    }
}

function Complete-AzureNvmeDisk {
    param (
        [object] $Disk,
        [string] $DriveLetter
    )

    if ($Disk.IsOffline) {
        Set-Disk -Number $Disk.Number -IsOffline $false
    }
    if ($Disk.IsReadOnly) {
        Set-Disk -Number $Disk.Number -IsReadOnly $false
    }

    if ($Disk.PartitionStyle -eq 'RAW') {
        $Disk = Initialize-Disk -Number $Disk.Number -PartitionStyle GPT -PassThru
    }

    $partition = Get-Partition -DiskNumber $Disk.Number -ErrorAction SilentlyContinue |
        Where-Object { $_.DriveLetter -eq $DriveLetter } |
        Select-Object -First 1

    if (-not $partition) {
        $partition = New-Partition -DiskNumber $Disk.Number -DriveLetter $DriveLetter -UseMaximumSize
    }

    $volume = Get-Volume -DriveLetter $DriveLetter -ErrorAction SilentlyContinue
    if (-not $volume -or [string]::IsNullOrEmpty($volume.FileSystem)) {
        Format-Volume -DriveLetter $DriveLetter -FileSystem NTFS -NewFileSystemLabel 'Temporary Storage' -Confirm:$false -Force | Out-Null
    }
}

function New-AzureNvmeStoragePool {
    param (
        [object[]] $DataDisks,
        [string] $PoolName,
        [string] $VirtualDiskName
    )

    $poolDisks = @(
        Get-PhysicalDisk -CanPool $true |
            Where-Object { $_.FriendlyName -like '*NVMe Direct Disk*' }
    )

    if ($poolDisks.Count -ne $DataDisks.Count) {
        throw 'Not all Azure NVMe data disks are available for the temporary storage pool.'
    }

    $storagePool = New-StoragePool -FriendlyName $PoolName -StorageSubsystemFriendlyName 'Windows Storage*' -PhysicalDisks $poolDisks -ResiliencySettingNameDefault Simple
    New-VirtualDisk -FriendlyName $VirtualDiskName -StoragePoolFriendlyName $storagePool.FriendlyName -NumberOfColumns $poolDisks.Count -PhysicalDiskRedundancy 0 -ResiliencySettingName Simple -UseMaximumSize
}

function Assert-AzureTemporaryDrive {
    param (
        [string] $DriveLetter
    )

    $volume = Get-ReadyTemporaryVolume -DriveLetter $DriveLetter
    $driveRoot = ('{0}:\' -f $DriveLetter)

    if (-not $volume -or $volume.FileSystem -ne 'NTFS' -or -not (Test-Path -LiteralPath $driveRoot -PathType Container)) {
        throw ('Azure temporary drive {0} is not a ready fixed NTFS volume.' -f $driveRoot)
    }
}

function Initialize-AzureNvmeTemporaryDrive {
    param (
        [string] $DriveLetter = 'D',
        [string] $PoolName = 'NVMePool',
        [string] $VirtualDiskName = 'NVMeTemporary',
        [switch] $Required,
        [int] $WaitSeconds = 0,
        [int] $RetrySeconds = 5
    )

    $existingVolume = Get-ReadyTemporaryVolume -DriveLetter $DriveLetter
    if ($existingVolume) {
        if ($Required) {
            Assert-AzureTemporaryDrive -DriveLetter $DriveLetter
        }
        return
    }

    $virtualDisk = Get-VirtualDisk -FriendlyName $VirtualDiskName -ErrorAction SilentlyContinue
    if ($virtualDisk) {
        Move-CdRomFromTemporaryDrive -DriveLetter $DriveLetter
        Complete-AzureNvmeDisk -Disk ($virtualDisk | Get-Disk) -DriveLetter $DriveLetter
        if ($Required) {
            Assert-AzureTemporaryDrive -DriveLetter $DriveLetter
        }
        return
    }

    $dataDisks = @(Wait-AzureNvmeDataDisks -WaitSeconds $WaitSeconds -RetrySeconds $RetrySeconds)
    if ($dataDisks.Count -eq 0) {
        if ($Required) {
            throw ('No unused Azure NVMe data disk became available within {0} seconds.' -f $WaitSeconds)
        }
        return
    }

    Move-CdRomFromTemporaryDrive -DriveLetter $DriveLetter

    if ($dataDisks.Count -eq 1) {
        Complete-AzureNvmeDisk -Disk $dataDisks[0] -DriveLetter $DriveLetter
    }
    else {
        $virtualDisk = New-AzureNvmeStoragePool -DataDisks $dataDisks -PoolName $PoolName -VirtualDiskName $VirtualDiskName
        Complete-AzureNvmeDisk -Disk ($virtualDisk | Get-Disk) -DriveLetter $DriveLetter
    }

    if ($Required) {
        Assert-AzureTemporaryDrive -DriveLetter $DriveLetter
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Initialize-AzureNvmeTemporaryDrive -DriveLetter $driveLetter -PoolName $poolName -VirtualDiskName $virtualDiskName -Required:$Required -WaitSeconds $WaitSeconds -RetrySeconds $RetrySeconds
}
