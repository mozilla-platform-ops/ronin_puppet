Describe "Puppet Windows Service" {
    Context "puppet service" {
        It "Puppet service exists" {
            Get-Service "puppet" | Should -Not -Be $null
        }
        It "Puppet service exists is disabled" {
            (Get-Service "puppet").Status | Should -Be "Stopped"
        }
    }
}
