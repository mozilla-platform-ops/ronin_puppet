Describe "WPTx64" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    BeforeAll {
        $workerFunction = $Hiera.'win-worker'.function
        $arch = (Get-WinFactsCustomOS).custom_win_os_arch
        $displayVersion = (Get-OSVersionExtended).DisplayVersion

        # Builders and aarch64 only get the base WPTx64 MSI.
        # x64 testers additionally get the Windows SDK, which installs
        # a newer WPTx64 whose name and version depend on the OS release.
        switch ($workerFunction) {
            "builder" {
                $expectedPackageName = "WPTx64"
                $expectedVersion = "10.1.16299.15"
            }
            "tester" {
                switch ("${arch}/${displayVersion}") {
                    "x64/25H2" {
                        $expectedPackageName = "WPTx64 (DesktopEditions)"
                        $expectedVersion = "10.1.22621.5040"
                    }
                    "x64/24H2" {
                        $expectedPackageName = "WPTx64 (DesktopEditions)"
                        $expectedVersion = "10.1.22621.5040"
                    }
                    "x64/22H2" {
                        $expectedPackageName = "WPTx64"
                        $expectedVersion = "10.1.19041.685"
                    }
                    default {
                        $expectedPackageName = "WPTx64"
                        $expectedVersion = "10.1.16299.15"
                    }
                }
            }
            default {
                $expectedPackageName = "WPTx64"
                $expectedVersion = "10.1.16299.15"
            }
        }

        $software = Get-InstalledSoftware | Where-Object {
            $PSItem.DisplayName -eq $expectedPackageName
        }
    }

    It "WPTx64 installed" {
        $software | Should -Not -Be $null
    }

    It "WPTx64 version" {
        $software.DisplayVersion | Should -Be $expectedVersion
    }
}
