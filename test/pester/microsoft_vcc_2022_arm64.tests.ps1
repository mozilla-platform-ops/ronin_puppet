Describe "Microsoft Visual C++ 2015 Redistributable" {
    BeforeAll {
        $software = Get-InstalledSoftware
        $vcc2022arm64_runtime = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2022 Arm64 Runtime - 14.42.34438"
        }
        $vcc2022arm64_redistributable = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2022 Redistributable (Arm64) - 14.42.34438"
        }
    }
    It "Microsoft Visual C++ 2022 Arm64 Runtime installed" {
        $vcc2022arm64_runtime | Should -Not -Be $Null
    }
    It "Microsoft Visual C++ 2022 Arm64 Runtime version" {
        $vcc2022arm64_runtime.DisplayVersion | Should -Be "14.42.34438"
    }
    It "Microsoft Visual C++ 2022 Redistributable (Arm64) installed" {
        $vcc2022arm64_redistributable | Should -Not -Be $Null
    }
    It "Microsoft Visual C++ 2022 Redistributable (Arm64) version" {
        $vcc2022arm64_redistributable.DisplayVersion | Should -Be "14.42.34438.0"
    }
}
