Describe "Nvidia GPU Drivers Downloaded" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    BeforeAll {
        $GPU = $Hiera.windows.gpu.name
    }
    It "Nvidia GPU Drivers are downloaded" {
        Test-Path "$systemdrive\Windows\Temp\$($GPU).exe" | Should -Be $true
    }
}
