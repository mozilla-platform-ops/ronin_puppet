function Add-WindowsCommandStub {
    param (
        [string] $Name,
        [scriptblock] $Body
    )

    if (-not (Get-Command -Name $Name -ErrorAction SilentlyContinue)) {
        Set-Item -Path ('Function:\global:{0}' -f $Name) -Value $Body
    }
}

Add-WindowsCommandStub -Name Get-Volume -Body {
    param ($DriveLetter, $ErrorAction)
}
Add-WindowsCommandStub -Name Get-VirtualDisk -Body {
    param ($FriendlyName, $ErrorAction)
}
Add-WindowsCommandStub -Name Get-Disk -Body {
    param ($ErrorAction)
}
Add-WindowsCommandStub -Name Get-CimInstance -Body {
    param ($ClassName, $ErrorAction)
}
Add-WindowsCommandStub -Name Set-CimInstance -Body {
    param ($InputObject, $Property)
}
Add-WindowsCommandStub -Name Set-Disk -Body {
    param ($Number, $IsOffline, $IsReadOnly)
}
Add-WindowsCommandStub -Name Initialize-Disk -Body {
    param ($Number, $PartitionStyle, [switch] $PassThru)
}
Add-WindowsCommandStub -Name Get-Partition -Body {
    param ($DiskNumber, $ErrorAction)
}
Add-WindowsCommandStub -Name New-Partition -Body {
    param ($DiskNumber, $DriveLetter, [switch] $UseMaximumSize)
}
Add-WindowsCommandStub -Name Format-Volume -Body {
    param ($DriveLetter, $FileSystem, $NewFileSystemLabel, [switch] $Confirm, [switch] $Force)
}
Add-WindowsCommandStub -Name Get-PhysicalDisk -Body {
    param ($CanPool)
}
Add-WindowsCommandStub -Name New-StoragePool -Body {
    param ($FriendlyName, $StorageSubsystemFriendlyName, $PhysicalDisks, $ResiliencySettingNameDefault)
}
Add-WindowsCommandStub -Name New-VirtualDisk -Body {
    param ($FriendlyName, $StoragePoolFriendlyName, $NumberOfColumns, $PhysicalDiskRedundancy, $ResiliencySettingName, [switch] $UseMaximumSize)
}
