#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

BeforeDiscovery { . "$PSScriptRoot/Settings.ps1" }

Describe 'Mozilla Maintenance Service' -Tag IntegrationTests -Skip:(-not $Tester) {
    BeforeAll {
        . "$PSScriptRoot/Settings.ps1"
        $Software = Get-ItemProperty -Path @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        ) -ErrorAction SilentlyContinue
    }

    It 'is installed' {
        ($Software | Where-Object DisplayName -EQ 'Mozilla Maintenance Service' | Select-Object -First 1).DisplayName |
            Should-BeString 'Mozilla Maintenance Service'
    }
    if (-not $Win10) {
        It 'has the service' { (Get-Service MozillaMaintenance).Name | Should-BeString 'MozillaMaintenance' }
        It 'trusts the Mozilla test certificate <_>' -ForEach @(
            'FA056CEBEFF3B1D0500A1FB37C2BD2F9CE4FB5D8'
            'EA66A61D6C382C8D1CA8C345EEB7D4DF4AFBEF18'
            'A13DC11A11F27619734BD4B73F2649FFDA3E6230'
        ) {
            (Get-ChildItem Cert:\LocalMachine\Root | Where-Object Thumbprint -EQ $_).Issuer | Should-BeString 'CN=Mozilla Fake CA'
        }
        It 'registers maintenance signing certificate <Index>' -ForEach @(
            @{ Index = 0; Issuer = 'DigiCert Trusted G4 Code Signing RSA4096 SHA384 2021 CA1'; Name = 'Mozilla Corporation' }
            @{ Index = 1; Issuer = 'Mozilla Fake CA'; Name = 'Mozilla Fake SPC' }
            @{ Index = 2; Issuer = 'DigiCert SHA2 Assured ID Code Signing CA'; Name = 'Mozilla Corporation' }
        ) {
            $key = "HKLM:\SOFTWARE\Mozilla\MaintenanceService\3932ecacee736d366d6436db0f55bce4\$Index"
            Get-ItemPropertyValue $key issuer | Should-BeString $Issuer
            Get-ItemPropertyValue $key name | Should-BeString $Name
        }
    }
}
