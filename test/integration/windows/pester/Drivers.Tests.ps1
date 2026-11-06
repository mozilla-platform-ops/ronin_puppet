#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Drivers' -Tag IntegrationTests {
    Context 'Defender driver path handling' {
        BeforeAll {
            . 'C:\ronin_puppet\modules\win_shared\files\defender_driver.ps1'
        }

        It 'renames the nested 24H2 hardware path drivers\wd\WdFilter.sys to WdFilter.sys.bak' {
            $driverDirectory = Join-Path $TestDrive 'System32\drivers'
            $driverPath = (Get-WdFilterDriverPaths -DriverDirectory $driverDirectory)[0]
            $driverPath | Should-MatchString '\\System32\\drivers\\wd\\WdFilter\.sys$'
            New-Item -ItemType Directory -Path (Split-Path $driverPath) -Force | Out-Null
            Set-Content -LiteralPath $driverPath -Value 'fixture'
            Rename-DefenderDriver -Name 'WdFilter' -Path $driverPath | Should-BeTrue
            Test-Path -LiteralPath $driverPath | Should-BeFalse
            Test-Path -LiteralPath "$driverPath.bak" | Should-BeTrue
        }

        It 'keeps the legacy top-level WdFilter path supported' {
            $driverDirectory = Join-Path $TestDrive 'System32\drivers'
            $driverPath = (Get-WdFilterDriverPaths -DriverDirectory $driverDirectory)[1]
            $driverPath | Should-MatchString '\\System32\\drivers\\WdFilter\.sys$'
            New-Item -ItemType Directory -Path (Split-Path $driverPath) -Force | Out-Null
            Set-Content -LiteralPath $driverPath -Value 'fixture'

            Rename-DefenderDriver -Name 'WdFilter' -Path $driverPath | Should-BeTrue
            Test-Path -LiteralPath $driverPath | Should-BeFalse
            Test-Path -LiteralPath "$driverPath.bak" | Should-BeTrue
        }
    }

    Context 'Windows 11 24H2 Kitchen image' -Skip:($env:WORKER_POOL_ID -ne 'win11-64-24h2-hw-kitchen') {
        It 'uses Windows 11 Enterprise build 26100' {
            $os = Get-CimInstance Win32_OperatingSystem
            $os.Caption | Should-MatchString '^Microsoft Windows 11 Enterprise'
            $os.Version | Should-MatchString '^10\.0\.26100(?:\.|$)'
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
