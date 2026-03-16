## CLEAN-UP Version should be in Hiera

Describe "Virtual Audio Cable" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    BeforeAll {
        $Software = Get-InstalledSoftware | Where-Object {
            $PSItem.DisplayName -like "Virtual Audio Cable*"
        }
    }
    It "Virtual Audio Cable is installed" {
        $Software.DisplayName | Should -Not -Be $Null
    }
    It "Virtual Audio Cable is version 4.64" {
        $Software.DisplayVersion | Should -Be "4.64"
    }
}
