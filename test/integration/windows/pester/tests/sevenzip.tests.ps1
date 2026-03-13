Describe "Common Tools" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    BeforeAll {
        $SevenZip = Get-InstalledSoftware | Where-Object {
            $_.DisplayName -match "Zip"
        }
    }

    Context "7-Zip" {
        It "7-Zip is installed" {
            $SevenZip.DisplayName | Should -Not -Be $null
        }

        It "7-Zip version is 25.00" {
            $SevenZip.DisplayVersion | Should -BeLike "25.00*"
        }
    }
}
