# Set up task storage before worker-runner starts. Never format an existing volume.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\configure_nvme_disk.ps1"

$workDrive = 'D:'
$volume = @(Get-Volume -FileSystemLabel 'Task Work Volume' -ErrorAction SilentlyContinue)
if ($volume.Count -gt 1) { throw 'More than one task work volume was found.' }

if ($volume.Count -eq 0) {
    $disk = Get-VirtualDisk -FriendlyName $virtualDiskName -ErrorAction SilentlyContinue | Get-Disk
    if (-not $disk) {
        $dataDisks = @(Wait-AzureNvmeDataDisks -WaitSeconds 30 -RetrySeconds 5)
        if ($dataDisks.Count -eq 1) {
            $disk = $dataDisks[0]
        } elseif ($dataDisks.Count -gt 1) {
            $disk = New-AzureNvmeStoragePool -DataDisks $dataDisks -PoolName $poolName -VirtualDiskName $virtualDiskName | Get-Disk
        }
    }

    if ($disk) {
        if ($disk.IsBoot -or $disk.IsSystem) { throw 'The work disk is an OS disk.' }
        if ($disk.IsOffline) { Set-Disk -Number $disk.Number -IsOffline $false }
        if ($disk.IsReadOnly) { Set-Disk -Number $disk.Number -IsReadOnly $false }
        if ($disk.PartitionStyle -eq 'RAW') {
            Initialize-Disk -Number $disk.Number -PartitionStyle GPT | Out-Null
        }
        $partition = @(Get-Partition -DiskNumber $disk.Number | Where-Object Type -eq 'Basic')
        if ($partition.Count -eq 0) {
            $partition = @(New-Partition -DiskNumber $disk.Number -UseMaximumSize)
        }
        if ($partition.Count -ne 1) { throw 'The work disk must have one data partition.' }
        $existing = $partition[0] | Get-Volume
        if ($existing.FileSystem) { throw 'Refusing to format an existing work disk file system.' }
        $format = @{ Partition = $partition[0]; NewFileSystemLabel = 'Task Work Volume'; Confirm = $false }
        if ([Environment]::OSVersion.Version.Build -ge 26100) {
            $format.DevDrive = $true
        } else {
            $format.FileSystem = 'NTFS'
        }
        $volume = @(Format-Volume @format)
    }
}

if ($volume.Count -eq 1) {
    $partition = $volume[0] | Get-Partition
    Move-CdRomFromTemporaryDrive -DriveLetter $driveLetter
    if ($partition.DriveLetter -ne $driveLetter) {
        Set-Partition -InputObject $partition -NewDriveLetter $driveLetter
    }
    if ($volume[0].FileSystem -eq 'ReFS') {
        $devDrive = fsutil.exe devdrv query $workDrive
        if ($LASTEXITCODE -ne 0) { throw 'Cannot query the task Dev Drive.' }
        if ($devDrive -notcontains 'This is a trusted developer volume.') {
            fsutil.exe devdrv trust $workDrive
            if ($LASTEXITCODE -ne 0) { throw 'Cannot trust the task Dev Drive.' }
        }
    }
}

# Older Azure SKUs can keep their existing NTFS temporary volume.
$ready = Get-ReadyTemporaryVolume -DriveLetter $driveLetter
if (-not $ready -or $ready.FileSystem -notin @('NTFS', 'ReFS')) {
    throw 'Task storage requires a fixed NTFS or ReFS volume on D:.'
}
$workDisk = Get-Partition -DriveLetter $driveLetter | Get-Disk
if (-not $workDisk -or $workDisk.IsBoot -or $workDisk.IsSystem) {
    throw 'Task storage on D: must be on a data disk.'
}

foreach ($name in @('tasks', 'caches', 'downloads')) {
    $path = "$workDrive\$name"
    $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Task storage must be a real directory: $path."
    }
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}

Write-Output "Task storage is ready on $workDrive."
