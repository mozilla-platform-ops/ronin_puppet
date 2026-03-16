Describe "Microsoft Visual C++ Runtimes" {
    BeforeAll {
        $software = Get-InstalledSoftware
        $vcc2015_2022_x64 = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2015-2022 Redistributable (x64) - 14.44.35211"
        }
        $vcc2015_2022_x86 = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2015-2022 Redistributable (x86) - 14.44.35211"
        }
        $vcc2022_x64_additional_runtime = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2022 X64 Additional Runtime - 14.44.35211"
        }
        $vcc2022_x64_minimum_runtime = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2022 X64 Minimum Runtime - 14.44.35211"
        }
        $vcc2022_x86_additional_runtime = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2022 X86 Additional Runtime - 14.44.35211"
        }
        $vcc2022_x86_minimum_runtime = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2022 X86 Minimum Runtime - 14.44.35211"
        }
    }
    It "Microsoft Visual C++ 2015-2022 Redistributable (x64) installed" {
        $vcc2015_2022_x64 | Should -Not -Be $Null
    }
    It "Microsoft Visual C++ 2015-2022 Redistributable (x64) version" {
        $vcc2015_2022_x64.DisplayVersion | Should -Be "14.44.35211.0"
    }

    It "Microsoft Visual C++ 2015-2022 Redistributable (x86) installed" {
        $vcc2015_2022_x86 | Should -Not -Be $Null
    }
    It "Microsoft Visual C++ 2015-2022 Redistributable (x86) version" {
        $vcc2015_2022_x86.DisplayVersion | Should -Be "14.44.35211.0"
    }

    It "Microsoft Visual C++ 2022 X64 Additional Runtime installed" {
        $vcc2022_x64_additional_runtime | Should -Not -Be $Null
    }
    It "Microsoft Visual C++ 2022 X64 Additional Runtime version" {
        $vcc2022_x64_additional_runtime.DisplayVersion | Should -Be "14.44.35211"
    }

    It "Microsoft Visual C++ 2022 X64 Minimum Runtime installed" {
        $vcc2022_x64_minimum_runtime | Should -Not -Be $Null
    }
    It "Microsoft Visual C++ 2022 X64 Minimum Runtime version" {
        $vcc2022_x64_minimum_runtime.DisplayVersion | Should -Be "14.44.35211"
    }

    It "Microsoft Visual C++ 2022 X86 Additional Runtime installed" {
        $vcc2022_x86_additional_runtime | Should -Not -Be $Null
    }
    It "Microsoft Visual C++ 2022 X86 Additional Runtime version" {
        $vcc2022_x86_additional_runtime.DisplayVersion | Should -Be "14.44.35211"
    }

    It "Microsoft Visual C++ 2022 X86 Minimum Runtime installed" {
        $vcc2022_x86_minimum_runtime | Should -Not -Be $Null
    }
    It "Microsoft Visual C++ 2022 X86 Minimum Runtime version" {
        $vcc2022_x86_minimum_runtime.DisplayVersion | Should -Be "14.44.35211"
    }
}
