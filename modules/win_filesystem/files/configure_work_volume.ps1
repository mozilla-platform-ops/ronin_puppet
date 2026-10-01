# Set up task storage before worker-runner starts. Never format an existing volume.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\configure_nvme_disk.ps1"

$mountPath = 'C:\work-volume'
$volume = @(Get-Volume -FileSystemLabel 'Task Work Volume' -ErrorAction SilentlyContinue)
if ($volume.Count -gt 1) { throw 'More than one task work volume was found.' }

if ($volume.Count -eq 0) {
    $disk = Get-VirtualDisk -FriendlyName 'NVMeTemporary' -ErrorAction SilentlyContinue | Get-Disk
    if (-not $disk) {
        $dataDisks = @(Wait-AzureNvmeDataDisks -WaitSeconds 30 -RetrySeconds 5)
        if ($dataDisks.Count -eq 1) {
            $disk = $dataDisks[0]
        } elseif ($dataDisks.Count -gt 1) {
            $disk = New-AzureNvmeStoragePool -DataDisks $dataDisks -PoolName 'NVMePool' -VirtualDiskName 'NVMeTemporary' | Get-Disk
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
    if ($partition.AccessPaths -notcontains "$mountPath\") {
        New-Item -ItemType Directory -Path $mountPath -Force | Out-Null
        Add-PartitionAccessPath -InputObject $partition -AccessPath "$mountPath\"
    }
    if ($volume[0].FileSystem -eq 'ReFS') {
        fsutil.exe devdrv trust $mountPath
        if ($LASTEXITCODE -ne 0) { throw 'Cannot trust the task Dev Drive.' }
    }
} else {
    # Older Azure SKUs have an NTFS temporary disk. Single-NVMe SKUs use C:.
    $temporary = Get-ReadyTemporaryVolume -DriveLetter D
    if ($temporary) {
        $mountPath = 'D:\work-volume'
    }
    New-Item -ItemType Directory -Path $mountPath -Force | Out-Null
}

foreach ($name in @('tasks', 'caches', 'downloads', 'hg-shared')) {
    $target = Join-Path $mountPath $name
    $path = "C:\$name"
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        if ($item.LinkType -ne 'Junction' -or $item.Target -ne $target) {
            throw "Unexpected link at $path."
        }
    } else {
        if ($item) {
            # Image seeds need a separate import step. Do not discard their data.
            if (Get-ChildItem -LiteralPath $path -Force | Select-Object -First 1) {
                throw "Cannot replace nonempty directory $path with a junction."
            }
            Remove-Item -LiteralPath $path -Force
        }
        New-Item -ItemType Junction -Path $path -Target $target | Out-Null
    }
}

# Task users need the shared Mercurial store. generic-worker sets task/cache ACLs.
icacls.exe 'C:\hg-shared' /grant '*S-1-1-0:(OI)(CI)F'
if ($LASTEXITCODE -ne 0) { throw 'Cannot set Mercurial store permissions.' }
[Environment]::SetEnvironmentVariable('HG_CACHE', 'C:\hg-cache', 'Machine')
Write-Output "Task storage is ready at $mountPath."
