Describe "Microsoft Visual C++ 2008 Redistributable" {
    BeforeAll {
        $software = Get-InstalledSoftware
        ## 2008 Redistributable
        $vcc2008 = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2008 Redistributable - x86 9.0.30729.17"
        }
    }
    Context "Microsoft Visual C++ 2008 Redistributable" {
        It "Visual c++ runtime 2008 x86 gets installed" {
            $vcc2008.DisplayName | Should -Not -Be $Null
        }
        It "Visual c++ runtime 2008 x86 version" {
            $vcc2008.DisplayVersion | Should -Be "9.0.30729"
        }
    }
}
