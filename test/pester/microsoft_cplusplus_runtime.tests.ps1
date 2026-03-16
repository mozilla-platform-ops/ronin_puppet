Describe "Microsoft Visual C++ Runtime 2015" {
    BeforeAll {
        $software = Get-InstalledSoftware
        $vccx86 = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2015 Redistributable (x86) - 14.0.23918"
        }
        $vccx64 = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2015 Redistributable (x64) - 14.0.23918"
        }
    }
    It "Visual c++ runtime 2015 x86 gets installed" {
        $vccx86.DisplayName | Should -Not -Be $Null
    }
    It "Visual c++ runtime 2015 x86 version" {
        $vccx86.DisplayVersion | Should -Be "14.0.23918.0"
    }
    It "Visual c++ runtime 2015 x64 gets installed" {
        $vccx64.DisplayName | Should -Not -Be $Null
    }
    It "Visual c++ runtime 2015 x64 version" {
        $vccx64.DisplayVersion | Should -Be "14.0.23918.0"
    }
}
