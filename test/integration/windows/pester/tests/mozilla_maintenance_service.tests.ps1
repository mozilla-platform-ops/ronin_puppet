Describe "Mozilla Maintenance Service" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    BeforeAll {
        $Software = Get-InstalledSoftware | Where-Object {
            $_.DisplayName -eq "Mozilla Maintenance Service"
        }
    }

    Context "Mozilla Maintenance Service" {
        It "is installed" {
            $Software.DisplayName | Should -Not -Be $null
        }

        It "Windows service exists" {
            Get-Service "MozillaMaintenance" | Should -Not -Be $null
        }
    }

    Context "Mozilla Maintenance Service certificates" -Foreach @(
        "FA056CEBEFF3B1D0500A1FB37C2BD2F9CE4FB5D8",
        "EA66A61D6C382C8D1CA8C345EEB7D4DF4AFBEF18",
        "A13DC11A11F27619734BD4B73F2649FFDA3E6230"
    ) {
        It "<_> exists in trusted root store" {
            $thumbprint = $_
            (Get-ChildItem Cert:\LocalMachine\Root |
            Where-Object { $_.Thumbprint -eq $thumbprint }).Issuer |
            Should -Be "CN=Mozilla Fake CA"
        }

        It "<_> has not expired" {
            $thumbprint = $_
            (Get-ChildItem Cert:\LocalMachine\Root |
            Where-Object { $_.Thumbprint -eq $thumbprint }).NotAfter |
            Should -BeGreaterThan (Get-Date)
        }
    }

    Context "Mozilla Maintenance Service ACL" {
        BeforeAll {
            $folder = 'C:\Program Files (x86)\Mozilla Maintenance Service'
            $acl = Get-Acl $folder
            $everyoneAce = $acl.Access | Where-Object {
                $_.IdentityReference -eq "Everyone" -and
                $_.FileSystemRights -eq "FullControl" -and
                $_.InheritanceFlags -eq "ContainerInherit, ObjectInherit" -and
                $_.AccessControlType -eq "Allow"
            }
        }

        It "Everyone has FullControl on the maintenance service directory" {
            $everyoneAce | Should -Not -BeNullOrEmpty
        }
    }

    Context "Mozilla Maintenance Service registry" {
        BeforeAll {
            $thawte = "HKLM:\SOFTWARE\Mozilla\MaintenanceService\3932ecacee736d366d6436db0f55bce4\0"
            $fake = "HKLM:\SOFTWARE\Mozilla\MaintenanceService\3932ecacee736d366d6436db0f55bce4\1"
            $mozRoot = "HKLM:\SOFTWARE\Mozilla\MaintenanceService\3932ecacee736d366d6436db0f55bce4\2"
        }

        It "registry root exists" {
            Test-Path "HKLM:\SOFTWARE\Mozilla\MaintenanceService\3932ecacee736d366d6436db0f55bce4" | Should -BeTrue
        }

        It "DigiCert issuer is present" {
            Get-ItemPropertyValue $thawte -Name "issuer" | Should -Be "DigiCert Trusted G4 Code Signing RSA4096 SHA384 2021 CA1"
        }

        It "DigiCert name is Mozilla Corporation" {
            Get-ItemPropertyValue $thawte -Name "name" | Should -Be "Mozilla Corporation"
        }

        It "Mozilla Fake CA issuer is present" {
            Get-ItemPropertyValue $fake -Name "issuer" | Should -Be "Mozilla Fake CA"
        }

        It "Mozilla Fake CA name is Mozilla Fake SPC" {
            Get-ItemPropertyValue $fake -Name "name" | Should -Be "Mozilla Fake SPC"
        }

        It "Mozilla root issuer is present" {
            Get-ItemPropertyValue $mozRoot -Name "issuer" | Should -Be "Digicert SHA2 Assured ID Code Signing CA"
        }

        It "Mozilla root name is Mozilla Corporation" {
            Get-ItemPropertyValue $mozRoot -Name "name" | Should -Be "Mozilla Corporation"
        }
    }
}
