Describe "Mercurial" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    BeforeAll {
        $HgInfo = Get-Command "hg.exe"
        $variant = $Hiera.'win-worker'.variant
        $win = $Hiera.windows

        $expectedSoftwareVersion = if ($variant.hg.version) { $variant.hg.version } else { $win.hg.version }
    }

    It "hg.exe is installed" {
        $HgInfo.Source | Should -Be "C:\Program Files\Mercurial\hg.exe"
    }

    It "Mercurial version matches hiera" -Skip {
        $HgInfo.FileVersionInfo.ProductVersion | Should -Be $expectedSoftwareVersion
    }
}
