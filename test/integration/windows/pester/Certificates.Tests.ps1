#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Certificates' -Tag IntegrationTests {
    Context 'Mozilla Maintenance Service' -Skip:(-not $Tester) {
        if (-not $Win10) {
            It 'trusts the Mozilla test certificate <_>' -ForEach @(
                'FA056CEBEFF3B1D0500A1FB37C2BD2F9CE4FB5D8'
                'EA66A61D6C382C8D1CA8C345EEB7D4DF4AFBEF18'
                'A13DC11A11F27619734BD4B73F2649FFDA3E6230'
            ) {
                (Get-ChildItem Cert:\LocalMachine\Root | Where-Object Thumbprint -EQ $_).Issuer | Should-BeString 'CN=Mozilla Fake CA'
            }
        }
    }
}
