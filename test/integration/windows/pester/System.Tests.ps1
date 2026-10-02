#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'System' -Tag IntegrationTests {
    Context 'Windows settings' {
        It 'uses UTC' { (Get-TimeZone).Id | Should-BeString 'UTC' }
        It 'uses the high performance power plan' {
            $output = powercfg.exe /getactivescheme
            $LASTEXITCODE | Should-Be 0
            $output | Should-MatchString '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
        }
    }
}
