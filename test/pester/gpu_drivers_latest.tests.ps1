Describe "Nvidia GPU Downloaded" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    BeforeAll {

        $variant = $Hiera.'win-worker'.variant
        $win = $Hiera.windows

        $GPU = if ($variant.'gpu-latest'.name) { $variant.'gpu-latest'.name } else { $win.'gpu-latest'.name }
    }
    It "Nvidia GPU Drivers are downloaded" {
        Test-Path "$systemdrive\Windows\Temp\$($GPU).exe" | Should -Be $true
    }
}
