BeforeAll {
    . (Join-Path $PSScriptRoot 'test_helpers.ps1')
    $scriptPath = Join-Path $PSScriptRoot '..\..\..\modules\win_scheduled_tasks\files\azure-maintainsystem.ps1'
    . $scriptPath
}

Describe 'Test-AzureNvmeTemporaryDriveRequired' {
    It 'requires the first-boot D drive for <vmSize>' -ForEach @(
        @{ vmSize = 'Standard_F8alds_v7' }
        @{ vmSize = 'Standard_F8ads_v7' }
    ) {
        Test-AzureNvmeTemporaryDriveRequired -vmSize $vmSize | Should -BeTrue
    }

    It 'does not select existing image paths for <vmSize>' -ForEach @(
        @{ vmSize = 'Standard_F8s_v2' }
        @{ vmSize = 'Standard_D8ads_v5' }
        @{ vmSize = 'Standard_D8alds_v6' }
        @{ vmSize = 'Standard_E8ads_v6' }
        @{ vmSize = 'Standard_NV12ads_A10_v5' }
        @{ vmSize = 'Standard_E8pds_v5' }
    ) {
        Test-AzureNvmeTemporaryDriveRequired -vmSize $vmSize | Should -BeFalse
    }
}

Describe 'Ensure-AzureNvmeTemporaryDrive' {
    BeforeEach {
        Mock Write-Log {}
        Mock Get-Volume { $null }
    }

    It 'does not inspect or change disks for an existing VM size' {
        Mock Test-Path { throw 'The NVMe script must not be inspected.' }

        { Ensure-AzureNvmeTemporaryDrive -vmSize 'Standard_F8s_v2' } | Should -Not -Throw

        Should -Invoke Test-Path -Times 0 -Exactly
        Should -Invoke Get-Volume -Times 0 -Exactly
    }

    It 'stops a selected v7 worker when the setup script is missing' {
        Mock Test-Path { $false }

        {
            Ensure-AzureNvmeTemporaryDrive -vmSize 'Standard_F8alds_v7'
        } | Should -Throw '*Required Azure NVMe setup script is missing*'

        Should -Invoke Get-Volume -Times 0 -Exactly
    }

    It 'verifies D after the selected v7 setup script runs' {
        $testScript = Join-Path $TestDrive 'configure_nvme_disk.ps1'
        Set-Content -Path $testScript -Value 'param ([switch] $Required, [int] $WaitSeconds, [int] $RetrySeconds)'

        Mock Get-Volume {
            [pscustomobject]@{
                DriveLetter = 'D'
                DriveType = 'Fixed'
                FileSystem = 'NTFS'
            }
        }

        {
            Ensure-AzureNvmeTemporaryDrive -vmSize 'Standard_F8alds_v7' -scriptPath $testScript
        } | Should -Not -Throw

        Should -Invoke Get-Volume -Times 1 -Exactly
    }
}

Describe 'Azure worker startup order' {
    It 'prepares D before the final Puppet run and Worker Runner startup' {
        $content = Get-Content -Path $scriptPath -Raw
        $mainStart = $content.IndexOf('If (($hand_off_ready')
        $ensureCall = $content.IndexOf('Ensure-AzureNvmeTemporaryDrive -vmSize $vm_size', $mainStart)
        $puppetCall = $content.IndexOf('Puppet-Run', $mainStart)
        $workerRunnerCall = $content.IndexOf('Start-WorkerRunner', $mainStart)

        $mainStart | Should -BeGreaterThan -1
        $ensureCall | Should -BeGreaterThan $mainStart
        $ensureCall | Should -BeLessThan $puppetCall
        $ensureCall | Should -BeLessThan $workerRunnerCall
    }
}
