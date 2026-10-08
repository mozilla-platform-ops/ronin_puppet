#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Maintenance ACLs' -Tag IntegrationTests {
    It 'protects maintenance directories' {
        & 'C:\ronin_puppet\test\windows_maintenance.ps1'
    }
}
