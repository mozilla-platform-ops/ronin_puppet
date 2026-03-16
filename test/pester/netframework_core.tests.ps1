Describe "Net Framework Core is installed" {
    It "NET Framework Core is installed" {
        Get-WindowsFeature -Name "NET-Framework-Core" | Should -Not -Be $Null
    }
}
