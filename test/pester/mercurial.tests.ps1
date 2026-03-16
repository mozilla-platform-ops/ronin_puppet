Describe "Mercurial" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    BeforeAll {
        $HgInfo = Get-Command "hg.exe"
        $variant = $Hiera.'win-worker'.variant
        $win = $Hiera.windows

        $ExpectedSoftwareVersion = if ($variant.hg.version) { $variant.hg.version } else { $win.hg.version }

    }

    It "Hg is installed" {
        $HgInfo.source | Should -Be "C:\Program Files\Mercurial\hg.exe"
    }
    It "Hg version matches hiera" -Skip {
        $HgInfo.FileVersionInfo.ProductVersion | Should -Be $ExpectedSoftwareVersion
    }
}
