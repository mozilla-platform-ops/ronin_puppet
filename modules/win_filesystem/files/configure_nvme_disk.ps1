if (Test-Path 'D:\') {
    return
}

# Based on Azure NVMe temporary disk guidance:
# https://learn.microsoft.com/en-us/azure/virtual-machines/enable-nvme-temp-faqs
$rawNvmeDisks = Get-PhysicalDisk -CanPool $true | Where-Object { $_.FriendlyName -like '*NVMe Direct Disk*' }

if (-not $rawNvmeDisks) {
    return
}

# Move CD-ROM off D: if needed so the temp disk can use D:
$cdRomDrive = Get-CimInstance -ClassName Win32_Volume | Where-Object { $_.DriveLetter -eq 'D:' -and $_.DriveType -eq 5 }
if ($cdRomDrive) {
    $cdRomDrive.DriveLetter = 'Z:'
    $null = $cdRomDrive.Put()
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
    $partition = New-Partition -DiskNumber $disk.Number -DriveLetter D -UseMaximumSize
}

$volume = Get-Volume -DriveLetter D -ErrorAction SilentlyContinue
if ($volume -and [string]::IsNullOrEmpty($volume.FileSystem)) {
    Format-Volume -DriveLetter D -FileSystem NTFS -NewFileSystemLabel 'Temporary Storage' -Confirm:$false -Force | Out-Null
}
