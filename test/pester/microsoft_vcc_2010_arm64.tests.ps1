Describe "Microsoft Visual C++ 2010 Redistributable" -Skip {
    BeforeAll {
        $software = Get-InstalledSoftware
        ## 2010 Redistributable
        $vcc2010x64 = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2010 x64 Redistributable - 10.0.30319"
        }
        $vcc2010x86 = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2010 x86 Redistributable - 10.0.30319"
        }
    }
    It "Microsoft Visual C++ 2010 x64 installed" {
        $vcc2010x64 | Should -Not -Be $Null
    }
    It "Microsoft Visual C++ 2010 x64 version" {
        $vcc2010x64.DisplayVersion | Should -Be "10.0.30319"
    }
    It "Microsoft Visual C++ 2010 x86 installed" {
        $vcc2010x86 | Should -Not -Be $Null
    }
    It "Microsoft Visual C++ 2010 x86 version" {
        $vcc2010x86.DisplayVersion | Should -Be "10.0.30319"
    }
}
