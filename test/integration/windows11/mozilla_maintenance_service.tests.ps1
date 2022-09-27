Describe "Mozilla Maintenance Service" {
    BeforeAll {
        $MozillaCerts = @(
            "FA056CEBEFF3B1D0500A1FB37C2BD2F9CE4FB5D8",
            "EA66A61D6C382C8D1CA8C345EEB7D4DF4AFBEF18",
            "A13DC11A11F27619734BD4B73F2649FFDA3E6230"
        )
    }
    Context "Mozilla Maintenance Service" -Foreach @(
        "FA056CEBEFF3B1D0500A1FB37C2BD2F9CE4FB5D8",
        "EA66A61D6C382C8D1CA8C345EEB7D4DF4AFBEF18",
        "A13DC11A11F27619734BD4B73F2649FFDA3E6230"
    ) {
        It "<_> exists in trusted root store" {
            $t = $_
           (Get-ChildItem Cert:\LocalMachine\Root |
            Where-Object { $PSItem.Thumbprint -eq $t }).Issuer |
            Should -Be "CN=Mozilla Fake CA"
        }
        It "<_> has not expired" {
            $t = $_
           (Get-ChildItem Cert:\LocalMachine\Root |
            Where-Object { $PSItem.Thumbprint -eq $t }).NotAfter |
            Should -BeGreaterThan (Get-Date)
        }
    }
    Context "Mozilla Maintenance Service Registry" {
        BeforeAll {
            $thawte = "HKLM:\SOFTWARE\Mozilla\MaintenanceService\3932ecacee736d366d6436db0f55bce4\0"
            $fake = "HKLM:\SOFTWARE\Mozilla\MaintenanceService\3932ecacee736d366d6436db0f55bce4\1"
            $MozRoot = "HKLM:\SOFTWARE\Mozilla\MaintenanceService\3932ecacee736d366d6436db0f55bce4\2"
        }
        It "Registry exists" {
            Test-Path "HKLM:\SOFTWARE\Mozilla\MaintenanceService\3932ecacee736d366d6436db0f55bce4" | Should -BeTrue
        }
        It "Thawte Code Signing CA Issuer" {
            Get-ItemPropertyValue $thawte -Name "issuer" | Should -Be "Thawte Code Signing CA - G2"
        }
        It "Thawte Code Signing CA Name" {
            Get-ItemPropertyValue $thawte -Name "name" | Should -Be "Mozilla Corporation"
        }
        It "MozFakeCA Issuer" {
            Get-ItemPropertyValue $fake -Name "issuer" | Should -Be "Mozilla Fake CA"
        }
        It "MozFakeCA Name" {
            Get-ItemPropertyValue $fake -Name "name" | Should -Be "Mozilla Fake SPC"
        }
        It "MozRoot Issuer" {
            Get-ItemPropertyValue $MozRoot -Name "issuer" | Should -Be "Digicert SHA2 Assured ID Code Signing CA"
        }
        It "MozRoot Name" {
            Get-ItemPropertyValue $MozRoot -Name "name" | Should -Be "Mozilla Corporation"
        }
    }
}