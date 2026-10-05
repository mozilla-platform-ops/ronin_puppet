#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Storage' -Tag IntegrationTests {
    Context 'Task storage' {
        if ($Win25) {
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
}
