Describe "Git" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    BeforeAll {
        $Git = Get-InstalledSoftware | Where-Object {
            $PSItem.DisplayName -match "Git"
        }
        $variant = $Hiera.'win-worker'.variant
        $win = $Hiera.windows

        $ExpectedSoftwareVersion = if ($variant.git.version) { $variant.git.version } else { $win.git.version }
    }
    It "Git is installed" {
        $Git.DisplayName | Should -Not -Be $null
    }

    It "Git Version is the same" -Skip {
        $Git.DisplayVersion | Should -Be $ExpectedSoftwareVersion
    }
}
