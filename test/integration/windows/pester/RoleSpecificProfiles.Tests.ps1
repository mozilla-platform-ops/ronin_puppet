#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

BeforeDiscovery { . "$PSScriptRoot/Settings.ps1" }

Describe 'Drivers' -Tag IntegrationTests {
    BeforeAll { . "$PSScriptRoot/Settings.ps1" }

    if ($Tester -or $Server25) {
        It 'caches the GPU installer' {
            $installer = "C:\Windows\Temp\$(Get-ExpectedValue gpu, name).exe"
            Test-Path $installer | Should-BeTrue
            if ($Win25) { (Get-Item $installer).Length | Should-BeGreaterThan 100000000 }
        }
    }
    if (($Win10 -or $Server25) -and $env:WORKER_POOL_ID -like '*gpu*') {
        It 'runs the configured NVIDIA A10-8Q driver' {
            $version = (Get-ExpectedValue gpu, name).Split('_')[0]
            $output = nvidia-smi.exe --query-gpu=name, driver_version --format=csv, noheader
            $LASTEXITCODE | Should-Be 0
            $output | Should-MatchString "^NVIDIA A10-8Q,\s*$([regex]::Escape($version))\s*$"
        }
    }
    if ($Tester -and -not $Arm) {
        It 'installs Virtual Audio Cable' {
            Test-Path "C:\VAC\$(Get-ExpectedValue vac, package_dir)" -PathType Container | Should-BeTrue
            $name = Get-ExpectedValue vac, service_name
            (Get-CimInstance Win32_SystemDriver -Filter "Name='$name'").Name | Should-BeString $name
            $device = Get-ExpectedValue vac, pnp_device_name
            (Get-PnpDevice -Class MEDIA | Where-Object FriendlyName -EQ $device | Select-Object -First 1).FriendlyName |
                Should-BeString $device
        }
    }
    if ($Win25) {
        It 'uses a cached NVIDIA installer without network access' {
            # Keep Puppet's Facter overrides in a child process, as in the old test.
            & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PSScriptRoot/OfflineNvidia.ps1"
            $LASTEXITCODE | Should-Be 0
        }
    }
}
