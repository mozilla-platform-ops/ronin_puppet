#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

BeforeDiscovery { . "$PSScriptRoot/Settings.ps1" }

Describe 'Task storage' -Tag IntegrationTests {
    BeforeAll { . "$PSScriptRoot/Settings.ps1" }

    It 'has the task drive' { Test-Path "$TaskDrive\" -PathType Container | Should-BeTrue }
    if ($Arm) {
        It 'has the ARM temporary drive' { Test-Path 'D:\' -PathType Container | Should-BeTrue }
    }
    if ($TaskDrive -eq 'C:') {
        It 'keeps the cache and page file on C:' {
            Get-ItemPropertyValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' HG_CACHE |
                Should-BeString 'C:\hg-cache'
            Get-ItemPropertyValue 'HKLM:\SOFTWARE\Mozilla\ronin_puppet' task_drive | Should-BeString 'C:'
            $paging = Get-ItemPropertyValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' PagingFiles
            ($paging -join "`n") | Should-MatchString '(?m)^C:\\pagefile\.sys 8192 8192$'
            ($paging -join "`n") | Should-NotMatchString 'D:\\'
        }
        It 'sets the <Setting> directory' -ForEach @(
            @{ Setting = 'tasks'; Directory = 'Users' }
            @{ Setting = 'caches'; Directory = 'caches' }
            @{ Setting = 'downloads'; Directory = 'downloads' }
        ) {
            Get-Content 'C:\worker-runner\runner.yml' -Raw |
                Should-MatchString "(?m)^\s+${Setting}Dir: 'C:\\$Directory'\s*$"
        }
        It 'has the shared Mercurial directory' { Test-Path 'C:\hg-shared' -PathType Container | Should-BeTrue }
    }
    if ($Win25) {
        It 'has the NVMe disk setup script' { Test-Path "$Ronin\configure_nvme_disk.ps1" | Should-BeTrue }
        It 'uses a fixed NTFS task volume' {
            $volume = Get-Volume -DriveLetter $TaskDrive[0]
            $volume.DriveType.ToString() | Should-BeString 'Fixed'
            $volume.FileSystem | Should-BeString 'NTFS'
        }
        It 'selects the Azure VM sizes that require NVMe setup' {
            . "$Ronin\maintainsystem.ps1"
            foreach ($size in @('Standard_D32ads_v7', 'Standard_F8alds_v7', 'Standard_F8ads_v7')) {
                Test-AzureNvmeTemporaryDriveRequired -vmSize $size | Should-BeTrue -Because $size
            }
            foreach ($size in @('Standard_F8s_v2', 'Standard_D8ads_v5', 'Standard_D8alds_v6',
                    'Standard_E8ads_v6', 'Standard_NV12ads_A10_v5', 'Standard_E8pds_v5')) {
                Test-AzureNvmeTemporaryDriveRequired -vmSize $size | Should-BeFalse -Because $size
            }
        }
    }
}
