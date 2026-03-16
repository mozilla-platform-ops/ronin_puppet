Describe "Microsoft Visual C++ Runtime 2022 x64" {
    BeforeAll {
        $software = Get-InstalledSoftware
        $vcc_minimum = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2022 X64 Minimum Runtime - 14.44.35211"
        }
        $vcc_additional = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2022 X64 Additional Runtime - 14.44.35211"
        }
        $vcc_all = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2015-2022 Redistributable (x64) - 14.44.35211"
        }
    }
    It "Visual c++ runtime 2022 x64 minimum gets installed" {
        $vcc_minimum.DisplayName | Should -Not -Be $Null
    }
    It "Visual c++ runtime 2022 x64 minimum version" {
        $vcc_minimum.DisplayVersion | Should -Be "14.44.35211"
    }
    It "Visual c++ runtime 2022 x64 additional gets installed" {
        $vcc_additional.DisplayName | Should -Not -Be $Null
    }
    It "Visual c++ runtime 2022 x64 additional version" {
        $vcc_additional.DisplayVersion | Should -Be "14.44.35211"
    }
    It "Visual c++ runtime 2015-2022 x64 gets installed" {
        $vcc_all.DisplayName | Should -Not -Be $Null
    }
    It "Visual c++ runtime 2015-2022 x64 version" {
        $vcc_all.DisplayVersion | Should -Be "14.44.35211.0"
    }
}