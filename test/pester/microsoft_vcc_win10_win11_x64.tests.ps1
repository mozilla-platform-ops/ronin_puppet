Describe "Microsoft Visual C++ Runtimes" {
    BeforeDiscovery {
        $arch = (Get-WinFactsCustomOS).custom_win_os_arch
        $displayVersion = (Get-OSVersionExtended).DisplayVersion
        $isWin11_25H2_x64 = "${arch}/${displayVersion}" -eq "x64/25H2"
    }

    Context "Legacy VC++ Runtime Packages" -Skip:$isWin11_25H2_x64 {
        BeforeAll {
            $software = Get-InstalledSoftware
            $vcc2015_2022_x64 = $software | Where-Object {
                $PSItem.DisplayName -eq "Microsoft Visual C++ 2015-2022 Redistributable (x64) - 14.40.33810"
            }
            $vcc2015_2022_x86 = $software | Where-Object {
                $PSItem.DisplayName -eq "Microsoft Visual C++ 2015-2022 Redistributable (x86) - 14.40.33810"
            }
            $vcc2022_x64_additional_runtime = $software | Where-Object {
                $PSItem.DisplayName -eq "Microsoft Visual C++ 2022 X64 Additional Runtime - 14.40.33810"
            }
            $vcc2022_x64_minimum_runtime = $software | Where-Object {
                $PSItem.DisplayName -eq "Microsoft Visual C++ 2022 X64 Minimum Runtime - 14.40.33810"
            }
            $vcc2022_x86_additional_runtime = $software | Where-Object {
                $PSItem.DisplayName -eq "Microsoft Visual C++ 2022 X86 Additional Runtime - 14.40.33810"
            }
            $vcc2022_x86_minimum_runtime = $software | Where-Object {
                $PSItem.DisplayName -eq "Microsoft Visual C++ 2022 X86 Minimum Runtime - 14.40.33810"
            }
        }

        It "Microsoft Visual C++ 2015-2022 Redistributable (x64) installed" {
            $vcc2015_2022_x64 | Should -Not -Be $Null
        }
        It "Microsoft Visual C++ 2015-2022 Redistributable (x64) version" {
            $vcc2015_2022_x64.DisplayVersion | Should -Be "14.40.33810.0"
        }

        It "Microsoft Visual C++ 2015-2022 Redistributable (x86) installed" {
            $vcc2015_2022_x86 | Should -Not -Be $Null
        }
        It "Microsoft Visual C++ 2015-2022 Redistributable (x86) version" {
            $vcc2015_2022_x86.DisplayVersion | Should -Be "14.40.33810.0"
        }

        It "Microsoft Visual C++ 2022 X64 Additional Runtime installed" {
            $vcc2022_x64_additional_runtime | Should -Not -Be $Null
        }
        It "Microsoft Visual C++ 2022 X64 Additional Runtime version" {
            $vcc2022_x64_additional_runtime.DisplayVersion | Should -Be "14.40.33810"
        }

        It "Microsoft Visual C++ 2022 X64 Minimum Runtime installed" {
            $vcc2022_x64_minimum_runtime | Should -Not -Be $Null
        }
        It "Microsoft Visual C++ 2022 X64 Minimum Runtime version" {
            $vcc2022_x64_minimum_runtime.DisplayVersion | Should -Be "14.40.33810"
        }

        It "Microsoft Visual C++ 2022 X86 Additional Runtime installed" {
            $vcc2022_x86_additional_runtime | Should -Not -Be $Null
        }
        It "Microsoft Visual C++ 2022 X86 Additional Runtime version" {
            $vcc2022_x86_additional_runtime.DisplayVersion | Should -Be "14.40.33810"
        }

        It "Microsoft Visual C++ 2022 X86 Minimum Runtime installed" {
            $vcc2022_x86_minimum_runtime | Should -Not -Be $Null
        }
        It "Microsoft Visual C++ 2022 X86 Minimum Runtime version" {
            $vcc2022_x86_minimum_runtime.DisplayVersion | Should -Be "14.40.33810"
        }
    }

    Context "Win11 25H2 x64 SDK Runtime Packages" -Skip:(-not $isWin11_25H2_x64) {
        BeforeAll {
            $software = Get-InstalledSoftware
            $sdkArmRedistributables = $software | Where-Object {
                $PSItem.DisplayName -eq "SDK ARM Redistributables"
            }
            $universalCrtRedistributable = $software | Where-Object {
                $PSItem.DisplayName -eq "Universal CRT Redistributable"
            }
            $windowsSdkRedistributables = $software | Where-Object {
                $PSItem.DisplayName -eq "Windows SDK Redistributables"
            }
        }

        It "SDK ARM Redistributables installed" {
            $sdkArmRedistributables | Should -Not -Be $null
        }
        It "SDK ARM Redistributables version" {
            $sdkArmRedistributables.DisplayVersion | Should -Be "10.1.22621.5040"
        }

        It "Universal CRT Redistributable installed" {
            $universalCrtRedistributable | Should -Not -Be $null
        }
        It "Universal CRT Redistributable version" {
            $universalCrtRedistributable.DisplayVersion | Should -Be "10.1.22621.5040"
        }

        It "Windows SDK Redistributables installed" {
            $windowsSdkRedistributables | Should -Not -Be $null
        }
        It "Windows SDK Redistributables version" {
            $windowsSdkRedistributables.DisplayVersion | Should -Be "10.1.22621.5040"
        }
    }
}
