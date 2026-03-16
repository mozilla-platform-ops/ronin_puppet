Describe "Microsoft Visual C++ 2015 Redistributable" {
    BeforeAll {
        $software = Get-InstalledSoftware
        $vcc2015x86 = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2015 Redistributable (x64) - 14.0.23918"
        }
        $vcc2015x86_additional_runtime = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2015 x86 Additional Runtime - 14.0.23918"
        }
        $vcc2015x86_minimum_runtime = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2015 x86 Minimum Runtime - 14.0.23918"
        }
    }
    It "Microsoft Visual C++ 2015 Redistributable (x64) installed" -Skip {
        $vcc2015x86 | Should -Not -Be $Null
    }
    It "Microsoft Visual C++ 2015 Redistributable (x64) version" -Skip {
        $vcc2015x86.DisplayVersion | Should -Be "14.0.23918.0"
    }
    It "Microsoft Visual C++ 2015 x86 Additional Runtime installed" -Skip {
        $vcc2015x86_additional_runtime | Should -Not -Be $Null
    }
    It "Microsoft Visual C++ 2015 x86 Additional Runtime version" {
        $vcc2015x86_additional_runtime.DisplayVersion | Should -Be "14.0.23918"
    }
    It "Microsoft Visual C++ 2015 x86 Minimum Runtime installed" {
        $vcc2015x86_minimum_runtime | Should -Not -Be $Null
    }
    It "Microsoft Visual C++ 2015 x86 Minimum Runtime version" {
        $vcc2015x86_minimum_runtime.DisplayVersion | Should -Be "14.0.23918"
    }
}
