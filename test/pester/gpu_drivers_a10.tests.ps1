Describe "Nvidia A10 GPU Drivers Downloaded" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    BeforeAll {
        $GPU = $Hiera.windows.gpu_a10.name
    }
    It "Nvidia A10 GPU Drivers are downloaded" {
        Test-Path "$systemdrive\Windows\Temp\$($GPU).exe" | Should -Be $true
    }
}
