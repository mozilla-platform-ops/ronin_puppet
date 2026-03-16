## CLEAN-UP Software versions should be in Hiera

Describe "Microsoft BinScope" {
    BeforeAll {
        $software = Get-InstalledSoftware
        $binscope = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft BinScope 2014"
        }
    }
    It "Microsoft BinScope 2014 gets installed" {
        $binscope.DisplayName | Should -Not -Be $Null
    }
    It "Microsoft BinScope 2014 version" {
        $binscope.DisplayVersion | Should -Be "7.0.7000.0"
    }
}
