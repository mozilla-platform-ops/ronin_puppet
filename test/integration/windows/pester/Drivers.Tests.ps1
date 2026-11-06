#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Drivers' -Tag IntegrationTests {
    Context 'Windows 11 24H2 Defender filter path' -Skip:($env:WORKER_POOL_ID -ne 'win11-64-24h2-hw-kitchen') {
        It 'uses the Windows 11 Enterprise 24H2 image' {
            $Win11_24H2 | Should-BeTrue
            (Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' ProductName) |
                Should-MatchString '^Windows 11 Enterprise'
        }

        It 'renames the WdFilter image path configured by the service' {
            $servicePath = 'HKLM:\SYSTEM\CurrentControlSet\Services\WdFilter'
            $imagePath = Get-ItemPropertyValue -LiteralPath $servicePath -Name ImagePath
            if ($imagePath.StartsWith('\SystemRoot\', [System.StringComparison]::OrdinalIgnoreCase)) {
                $driverPath = Join-Path $env:SystemRoot $imagePath.Substring('\SystemRoot\'.Length)
            } else {
                $driverPath = [System.Environment]::ExpandEnvironmentVariables($imagePath)
            }

            $driverPath | Should-MatchString '\\System32\\drivers\\wd\\WdFilter\.sys$'
            Test-Path -LiteralPath $driverPath | Should-BeFalse
            Test-Path -LiteralPath "$driverPath.bak" | Should-BeTrue
        }

        It 'reports the renamed WdFilter binary in the Defender check' {
            $checkScript = 'C:\ronin_puppet\modules\win_nsclient\files\check_defender.ps1'
            $output = & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $checkScript
            ($output -join ' ') | Should-MatchString 'WdFilter.sys=renamed bak=yes'
        }
    }

    Context 'GPU and audio drivers' {
        if (($Win10 -or $Server25) -and $env:WORKER_POOL_ID -like '*gpu*') {
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
