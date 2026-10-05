#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Drivers' -Tag IntegrationTests {
    Context 'GPU and audio drivers' {
        if ($env:WORKER_POOL_ID -like '*gpu*') {
            It 'runs the configured NVIDIA A10-8Q driver' {
                $version = (Get-HieraValue 'windows.gpu.name').Split('_')[0]
                $output = nvidia-smi.exe '--query-gpu=name,driver_version' '--format=csv,noheader'
                $LASTEXITCODE | Should-Be 0
                $output | Should-MatchString "^NVIDIA A10-8Q,\s*$([regex]::Escape($version))\s*$"
            }
        }
        if ($Tester -and -not $Arm) {
            It 'installs Virtual Audio Cable' {
                $packageDir = Get-HieraValue 'win-worker.variant.vac.package_dir', 'win-worker.vac.package_dir', 'windows.vac.package_dir'
                Test-Path "C:\VAC\$packageDir" -PathType Container | Should-BeTrue
                $name = Get-HieraValue 'win-worker.variant.vac.service_name', 'win-worker.vac.service_name', 'windows.vac.service_name'
                (Get-CimInstance Win32_SystemDriver -Filter "Name='$name'").Name | Should-BeString $name
                $device = Get-HieraValue 'win-worker.variant.vac.pnp_device_name', 'win-worker.vac.pnp_device_name', 'windows.vac.pnp_device_name'
                (Get-PnpDevice -Class MEDIA | Where-Object FriendlyName -EQ $device | Select-Object -First 1).FriendlyName |
                    Should-BeString $device
            }
        }
    }
}
