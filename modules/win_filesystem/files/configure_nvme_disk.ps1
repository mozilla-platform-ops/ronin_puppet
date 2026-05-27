$ErrorActionPreference = 'Stop'

$driveLetter = 'D'
$volumeLabel = 'Temporary Storage'

function Test-DevDriveFormatSupported {
    $formatVolumeCommand = Get-Command -Name Format-Volume -ErrorAction SilentlyContinue

    return $formatVolumeCommand -and $formatVolumeCommand.Parameters.ContainsKey('DevDrive')
}

function Test-DevDrive {
    param (
        [string] $DriveRoot
    )

    $queryOutput = & fsutil.exe devdrv query $DriveRoot 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    $queryText = $queryOutput -join "`n"
    return ($queryText -match 'developer volume') -and ($queryText -notmatch 'not a developer volume')
}

function Clear-PageFileSetting {
    param (
        [string] $DriveLetter
    )

    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
    if ($computerSystem -and $computerSystem.AutomaticManagedPagefile) {
        Set-CimInstance -InputObject $computerSystem -Property @{ AutomaticManagedPagefile = $false }
    }

    Get-CimInstance -ClassName Win32_PageFileSetting -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "${DriveLetter}:\*" } |
        ForEach-Object { Remove-CimInstance -InputObject $_ }
}

function Format-TemporaryVolume {
    param (
        [string] $DriveLetter,
        [bool] $UseDevDrive
    )

    $volume = Get-Volume -DriveLetter $DriveLetter -ErrorAction SilentlyContinue
    if (-not $volume) {
        return
    }

    if ($UseDevDrive) {
        if (Test-DevDrive -DriveRoot "${DriveLetter}:\") {
            & fsutil.exe devdrv trust "${DriveLetter}:\" | Out-Null
            return
        }

        Clear-PageFileSetting -DriveLetter $DriveLetter
        Format-Volume -DriveLetter $DriveLetter -DevDrive -NewFileSystemLabel $volumeLabel -Confirm:$false -Force | Out-Null
        & fsutil.exe devdrv trust "${DriveLetter}:\" | Out-Null
        return
    }

    if ([string]::IsNullOrEmpty($volume.FileSystem)) {
        Format-Volume -DriveLetter $DriveLetter -FileSystem NTFS -NewFileSystemLabel $volumeLabel -Confirm:$false -Force | Out-Null
    }
}

# Based on Azure NVMe temporary disk guidance:
# https://learn.microsoft.com/en-us/azure/virtual-machines/enable-nvme-temp-faqs
$useDevDrive = Test-DevDriveFormatSupported

# Move CD-ROM off D: if needed so the temp disk can use D:
$cdRomDrive = Get-CimInstance -ClassName Win32_Volume | Where-Object { $_.DriveLetter -eq "${driveLetter}:" -and $_.DriveType -eq 5 }
if ($cdRomDrive) {
    Set-CimInstance -InputObject $cdRomDrive -Property @{ DriveLetter = 'Z:' }
}

$volume = Get-Volume -DriveLetter $driveLetter -ErrorAction SilentlyContinue
if ($volume) {
    Format-TemporaryVolume -DriveLetter $driveLetter -UseDevDrive $useDevDrive
    return
}

$rawNvmeDisks = Get-PhysicalDisk -CanPool $true | Where-Object { $_.FriendlyName -like '*NVMe Direct Disk*' }

if (-not $rawNvmeDisks) {
    return
}

$poolName = 'NVMePool'
$virtualDiskName = 'NVMeTemporary'

$storagePool = Get-StoragePool -FriendlyName $poolName -ErrorAction SilentlyContinue
if (-not $storagePool) {
    $storagePool = New-StoragePool -FriendlyName $poolName -StorageSubsystemFriendlyName 'Windows Storage*' -PhysicalDisks $rawNvmeDisks -ResiliencySettingNameDefault Simple
}

$virtualDisk = Get-VirtualDisk -FriendlyName $virtualDiskName -ErrorAction SilentlyContinue
if (-not $virtualDisk) {
    $virtualDisk = New-VirtualDisk -FriendlyName $virtualDiskName -StoragePoolFriendlyName $poolName -NumberOfColumns @($rawNvmeDisks).Count -PhysicalDiskRedundancy 0 -ResiliencySettingName 'Simple' -UseMaximumSize
}

$disk = $virtualDisk | Get-Disk
if ($disk.PartitionStyle -eq 'RAW') {
    $disk = $disk | Initialize-Disk -PartitionStyle GPT -PassThru
}

$partition = Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -eq 'D' } | Select-Object -First 1
if (-not $partition) {
    $partition = New-Partition -DiskNumber $disk.Number -DriveLetter $driveLetter -UseMaximumSize
}

Format-TemporaryVolume -DriveLetter $driveLetter -UseDevDrive $useDevDrive
