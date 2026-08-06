BeforeAll {
    . (Join-Path $PSScriptRoot 'test_helpers.ps1')
    $scriptPath = Join-Path $PSScriptRoot '..\..\..\modules\win_filesystem\files\configure_nvme_disk.ps1'
    . $scriptPath
}

Describe 'Initialize-AzureNvmeTemporaryDrive' {
    BeforeEach {
        Mock Get-Volume { $null }
        Mock Get-VirtualDisk { $null }
        Mock Get-Disk { @() }
        Mock Get-CimInstance { $null }
        Mock Set-CimInstance {}
        Mock Set-Disk {}
        Mock Initialize-Disk {}
        Mock Get-Partition { $null }
        Mock New-Partition {}
        Mock Format-Volume {}
        Mock Get-PhysicalDisk { @() }
        Mock New-StoragePool {}
        Mock New-VirtualDisk {}
        Mock Start-Sleep {}
        Mock Test-Path { $true }
    }

    It 'leaves an existing fixed NTFS D drive unchanged' {
        Mock Get-Volume {
            [pscustomobject]@{
                DriveLetter = 'D'
                DriveType = 'Fixed'
                FileSystem = 'NTFS'
            }
        }

        Initialize-AzureNvmeTemporaryDrive -Required
        Initialize-AzureNvmeTemporaryDrive -Required

        Should -Invoke Get-Disk -Times 0 -Exactly
        Should -Invoke Set-CimInstance -Times 0 -Exactly
        Should -Invoke Initialize-Disk -Times 0 -Exactly
        Should -Invoke New-Partition -Times 0 -Exactly
        Should -Invoke Format-Volume -Times 0 -Exactly
    }

    It 'does not change a non-NVMe image that has no unused NVMe disk' {
        Initialize-AzureNvmeTemporaryDrive

        Should -Invoke Get-Disk -Times 1 -Exactly
        Should -Invoke Set-CimInstance -Times 0 -Exactly
        Should -Invoke Initialize-Disk -Times 0 -Exactly
        Should -Invoke New-Partition -Times 0 -Exactly
        Should -Invoke Format-Volume -Times 0 -Exactly
    }

    It 'does not change an initialized NVMe disk on an existing image' {
        Mock Get-Disk {
            @(
                [pscustomobject]@{
                    Number = 2
                    FriendlyName = 'Microsoft NVMe Direct Disk'
                    IsBoot = $false
                    IsSystem = $false
                    PartitionStyle = 'GPT'
                }
            )
        }

        Initialize-AzureNvmeTemporaryDrive

        Should -Invoke Get-Disk -Times 1 -Exactly
        Should -Invoke Set-CimInstance -Times 0 -Exactly
        Should -Invoke Initialize-Disk -Times 0 -Exactly
        Should -Invoke New-Partition -Times 0 -Exactly
        Should -Invoke Format-Volume -Times 0 -Exactly
    }

    It 'retries and stops when a required NVMe disk does not appear' {
        {
            Initialize-AzureNvmeTemporaryDrive -Required -WaitSeconds 10 -RetrySeconds 5
        } | Should -Throw '*No unused Azure NVMe data disk became available within 10 seconds*'

        Should -Invoke Get-Disk -Times 3 -Exactly
        Should -Invoke Start-Sleep -Times 2 -Exactly
        Should -Invoke Set-CimInstance -Times 0 -Exactly
        Should -Invoke Initialize-Disk -Times 0 -Exactly
    }

    It 'moves the CD-ROM and creates D from one unused NVMe disk' {
        $script:volumeCallCount = 0
        $rawDisk = [pscustomobject]@{
            Number = 2
            FriendlyName = 'Microsoft NVMe Direct Disk'
            IsBoot = $false
            IsSystem = $false
            IsOffline = $false
            IsReadOnly = $false
            PartitionStyle = 'RAW'
        }
        $initializedDisk = $rawDisk.PSObject.Copy()
        $initializedDisk.PartitionStyle = 'GPT'

        Mock Get-Volume {
            $script:volumeCallCount++
            if ($script:volumeCallCount -ge 3) {
                [pscustomobject]@{
                    DriveLetter = 'D'
                    DriveType = 'Fixed'
                    FileSystem = 'NTFS'
                }
            }
        }
        Mock Get-Disk { @($rawDisk) }
        Mock Get-CimInstance {
            [pscustomobject]@{
                DriveLetter = 'D:'
                DriveType = 5
            }
        }
        Mock Initialize-Disk { $initializedDisk }
        Mock New-Partition {
            [pscustomobject]@{
                DiskNumber = 2
                DriveLetter = 'D'
            }
        }

        Initialize-AzureNvmeTemporaryDrive -Required

        Should -Invoke Set-CimInstance -Times 1 -Exactly
        Should -Invoke Initialize-Disk -Times 1 -Exactly
        Should -Invoke New-Partition -Times 1 -Exactly
        Should -Invoke Format-Volume -Times 1 -Exactly
    }
}
