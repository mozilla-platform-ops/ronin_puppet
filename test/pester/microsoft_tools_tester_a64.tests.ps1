#CLEAN-UP Software versions should be in Hiera

## Skip if this is run on a builder
Describe "Microsoft Tools - Tester" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    BeforeAll {
        $Directories = Get-WinFactsDirectories
        $software = Get-InstalledSoftware | Where-Object {
            $PSItem.DisplayName -eq "WPTx64"
        }
    }
    It "WPTx64 is installed" {
        $software | Should -Not -Be $null
    }
}
