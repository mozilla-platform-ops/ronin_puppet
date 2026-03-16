Describe "Mozilla Maintenance Service" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    BeforeAll {
        $MozillaCerts = @(
            "FA056CEBEFF3B1D0500A1FB37C2BD2F9CE4FB5D8",
            "EA66A61D6C382C8D1CA8C345EEB7D4DF4AFBEF18",
            "A13DC11A11F27619734BD4B73F2649FFDA3E6230"
        )
        $Software = Get-InstalledSoftware | Where-Object {
            $PSItem.DisplayName -eq "Mozilla Maintenance Service"
        }
    }
    Context "Mozilla Maintenance Program" {
        It "Mozilla Maintenance Service is installed" {
            $Software.DisplayName | Should -Not -Be $Null
        }
        It "Mozilla Maintenance Service Windows Service exists" {
            Get-Service "MozillaMaintenance" | Should -Not -Be $null
        }
    }
    Context "Mozilla Maintenance Service Certificates" -Foreach @(
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
    Context "Mozilla Maintenance Service ACL" {
        BeforeAll {
            $Folder = 'C:\Program Files (x86)\Mozilla Maintenance Service'
            $Acl = Get-Acl $Folder
            $EveryoneAce = $Acl.Access | Where-Object {
                $PSItem.IdentityReference -eq "Everyone" -and
                $PSItem.FileSystemRights -eq "FullControl" -and
                $PSItem.InheritanceFlags -eq "ContainerInherit, ObjectInherit" -and
                $PSItem.AccessControlType -eq "Allow"
            }
        }
        It "Everyone has FullControl on maintenance service directory" {
            $EveryoneAce | Should -Not -BeNullOrEmpty
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
        It "DigiCert Trusted G4 Code Signing RSA4096 SHA384 2021 CA1" {
            Get-ItemPropertyValue $thawte -Name "issuer" | Should -Be "DigiCert Trusted G4 Code Signing RSA4096 SHA384 2021 CA1"
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
