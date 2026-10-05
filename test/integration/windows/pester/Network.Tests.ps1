#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Network' -Tag IntegrationTests {
    Context 'Windows settings' {
        It 'uses a private network profile' {
            ((Get-NetConnectionProfile).NetworkCategory -join ',') | Should-MatchString 'Private'
        }
        It 'allows ICMP echo requests' {
            (Get-NetFirewallRule -DisplayName 'ICMP Allow incoming V4 echo request' | Select-Object -First 1).Enabled.ToString() |
                Should-BeString 'True'
        }
    }
}
