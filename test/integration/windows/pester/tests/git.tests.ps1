Describe "Git" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    BeforeAll {
        $Git = Get-InstalledSoftware | Where-Object {
            $_.DisplayName -match "Git"
        }
        $variant = $Hiera.'win-worker'.variant
        $win = $Hiera.windows

        $expectedSoftwareVersion = if ($variant.git.version) { $variant.git.version } else { $win.git.version }
    }

    It "Git is installed" {
        $Git.DisplayName | Should -Not -Be $null
    }

    It "Git version matches hiera" -Skip {
        $Git.DisplayVersion | Should -Be $expectedSoftwareVersion
    }
}
