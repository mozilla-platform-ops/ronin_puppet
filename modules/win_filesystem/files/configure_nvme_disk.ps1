If (-Not (Test-Path "D:\")) {
    ## From https://learn.microsoft.com/en-us/azure/virtual-machines/enable-nvme-temp-faqs#azure-powershell-script
    # Select the raw NVMe disks to partition and format 
    $RawNvmeDisks = Get-PhysicalDisk -CanPool $True | Where-Object { $_.FriendlyName.contains("NVMe Direct Disk") } 
    # Create a pool of the existing disks
    New-StoragePool -FriendlyName NVMePool -StorageSubsystemFriendlyName "Windows Storage*" -PhysicalDisks $RawNvmeDisks -ResiliencySettingNameDefault Simple 
    #Create a new disk, initialize, partition, and format
    $Disk = New-VirtualDisk -FriendlyName NVMeTemporary -StoragePoolFriendlyName NVMePool -NumberOfColumns @($RawNvmeDisks).count  -PhysicalDiskRedundancy 0 -ResiliencySettingName "Simple" -UseMaximumSize
    $Disk | Initialize-Disk 
    #Create a partition and format. Ignore the pop-up. 
    New-Partition -DiskId $Disk.UniqueId -DriveLetter D -UseMaximumSize | Format-Volume
}