$ErrorActionPreference = 'Stop'

$driveLetter = 'D'
$volumeLabel = 'Temporary Storage'

function Test-DevDriveFormatSupported {
    $formatVolumeCommand = Get-Command -Name Format-Volume -ErrorAction SilentlyContinue

    return $formatVolumeCommand -and $formatVolumeCommand.Parameters.ContainsKey('DevDrive')
}

function Get-DevDriveState {
    param (
        [string] $DriveRoot
    )

    $queryOutput = & fsutil.exe devdrv query $DriveRoot 2>$null
    if ($LASTEXITCODE -ne 0) {
        return 'None'
    }

    $queryText = $queryOutput -join "`n"
    if ($queryText -match 'trusted developer volume') {
        return 'Trusted'
    }
    if (($queryText -match 'developer volume') -and ($queryText -notmatch 'not a developer volume')) {
        return 'Untrusted'
    }

    return 'None'
}

function Set-TrustedDevDrive {
    param (
        [string] $DriveRoot
    )

    & fsutil.exe devdrv trust $DriveRoot | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to trust Dev Drive $DriveRoot."
    }
}

function Test-ActivePageFileOnDrive {
    param (
        [string] $DriveLetter
    )

    $driveRoot = "${DriveLetter}:\"
    $pageFileUsage = Get-CimInstance -ClassName Win32_PageFileUsage -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "${driveRoot}*" } | Select-Object -First 1

    return ($null -ne $pageFileUsage)
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
        $driveRoot = "${DriveLetter}:\"

        switch (Get-DevDriveState -DriveRoot $driveRoot) {
            'Trusted' {
                return
            }
            'Untrusted' {
                Set-TrustedDevDrive -DriveRoot $driveRoot
                return
            }
        }

        if (Test-ActivePageFileOnDrive -DriveLetter $DriveLetter) {
            throw "Cannot format ${DriveLetter}: as a Dev Drive because it has an active pagefile. Move the pagefile off ${DriveLetter}: and reboot before retrying Dev Drive conversion."
        }

        Format-Volume -DriveLetter $DriveLetter -DevDrive -NewFileSystemLabel $volumeLabel -Confirm:$false -Force | Out-Null
        Set-TrustedDevDrive -DriveRoot $driveRoot
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

$poolName = 'NVMePool'
$virtualDiskName = 'NVMeTemporary'

$storagePool = Get-StoragePool -FriendlyName $poolName -ErrorAction SilentlyContinue
if (-not $storagePool) {
    $poolDisks = @(Get-PhysicalDisk -CanPool $true | Where-Object { $_.FriendlyName -like '*NVMe Direct Disk*' })
    if ($poolDisks.Count -eq 0) {
        return
    }
    $storagePool = New-StoragePool -FriendlyName $poolName -StorageSubsystemFriendlyName 'Windows Storage*' -PhysicalDisks $poolDisks -ResiliencySettingNameDefault Simple
}
else {
    $poolDisks = @($storagePool | Get-PhysicalDisk)
}

$virtualDisk = Get-VirtualDisk -FriendlyName $virtualDiskName -ErrorAction SilentlyContinue
if (-not $virtualDisk) {
    $virtualDiskParameters = @{
        FriendlyName             = $virtualDiskName
        StoragePoolFriendlyName  = $poolName
        PhysicalDiskRedundancy   = 0
        ResiliencySettingName    = 'Simple'
        UseMaximumSize           = $true
    }
    if ($poolDisks.Count -gt 0) {
        $virtualDiskParameters['NumberOfColumns'] = $poolDisks.Count
    }
    $virtualDisk = New-VirtualDisk @virtualDiskParameters
}

$disk = $virtualDisk | Get-Disk
if ($disk.PartitionStyle -eq 'RAW') {
    $disk = $disk | Initialize-Disk -PartitionStyle GPT -PassThru
}

if (-not (Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -eq $driveLetter } | Select-Object -First 1)) {
    New-Partition -DiskNumber $disk.Number -DriveLetter $driveLetter -UseMaximumSize | Out-Null
}

Format-TemporaryVolume -DriveLetter $driveLetter -UseDevDrive $useDevDrive
