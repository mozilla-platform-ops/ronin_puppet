Describe "Mozilla Build" -Skip:(Assert-IsBuilder) {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
        C:\mozilla-build\python3\python.exe -m pip freeze --all > C:\requirements.txt
    }

    BeforeAll {
        $software = Get-InstalledSoftware
        $mercurial = $software | Where-Object {
            $_.DisplayName -like "Mercurial*"
        }
        $mms = $software | Where-Object {
            $_.DisplayName -like "Mozilla Maintenance Service*"
        }
        $pipPackages = Get-Content C:\requirements.txt
        $variant = $Hiera.'win-worker'.variant
        $win = $Hiera.windows

        $hgExpectedSoftwareVersion = if ($variant.hg.version) { $variant.hg.version } else { $win.hg.version }
        $mozillaBuildExpectedSoftwareVersion = if ($variant.mozilla_build.version) { $variant.mozilla_build.version } else { $win.mozilla_build.version }
        $psutilExpectedSoftwareVersion = if ($variant.mozilla_build.psutil_version) { $variant.mozilla_build.psutil_version } else { $win.mozilla_build.psutil_version }
        $zstandardExpectedSoftwareVersion = if ($variant.mozilla_build.zstandard_version) { $variant.mozilla_build.zstandard_version } else { $win.mozilla_build.zstandard_version }
        $py3PipExpectedSoftwareVersion = if ($variant.mozilla_build.py3_pip_version) { $variant.mozilla_build.py3_pip_version } else { $win.mozilla_build.py3_pip_version }
    }

    Context "Installation" {
        It "Mozilla-Build folder exists" {
            Test-Path "C:\mozilla-build" | Should -Be $true
        }

        It "Mozilla-Build version matches hiera" {
            Get-Content "C:\mozilla-build\VERSION" | Should -Be $mozillaBuildExpectedSoftwareVersion
        }

        It "msys2 sh.exe exists" {
            Test-Path "C:\mozilla-build\msys2\usr\bin\sh.exe" | Should -Be $true
        }

        It "Mozilla Maintenance Service is installed" {
            $mms.DisplayName | Should -Not -Be $null
        }

        It "Mozilla Maintenance Service version is 27.0a1" {
            $mms.DisplayVersion | Should -Be "27.0a1"
        }
    }

    Context "Pip" {
        It "Certifi is installed" {
            $certifi = ($pipPackages | Where-Object { $_ -match "Certifi" }) -split "=="
            $certifi | Should -Not -Be $null
        }

        It "PSUtil is installed" {
            $psutil = ($pipPackages | Where-Object { $_ -match "PSUtil" }) -split "=="
            $psutil | Should -Not -Be $null
        }

        It "PSUtil version matches hiera" {
            $psutil = ($pipPackages | Where-Object { $_ -match "PSUtil" }) -split "=="
            $psutil[1] | Should -Be $psutilExpectedSoftwareVersion
        }

        It "zstandard is installed" {
            $zstandard = ($pipPackages | Where-Object { $_ -match "zstandard" }) -split "=="
            $zstandard | Should -Not -Be $null
        }

        It "zstandard version matches hiera" {
            $zstandard = ($pipPackages | Where-Object { $_ -match "zstandard" }) -split "=="
            $zstandard[1] | Should -Be $zstandardExpectedSoftwareVersion
        }

        It "pip is installed" {
            $py3pip = ($pipPackages | Where-Object { $_ -match "^pip==" }) -split "=="
            $py3pip | Should -Not -Be $null
        }

        It "pip version matches hiera" {
            $py3pip = ($pipPackages | Where-Object { $_ -match "^pip==" }) -split "=="
            $py3pip[1] | Should -Be $py3PipExpectedSoftwareVersion
        }
    }

    Context "Mercurial" -Skip {
        It "Mercurial is installed" {
            $mercurial.DisplayName | Should -Not -Be $null
        }

        It "Mercurial major version matches hiera" {
            ([Version]$mercurial.DisplayVersion).Major | Should -Be $hgExpectedSoftwareVersion.Major
        }

        It "Mercurial minor version matches hiera" {
            ([Version]$mercurial.DisplayVersion).Minor | Should -Be $hgExpectedSoftwareVersion.Minor
        }

        It "Mercurial build version matches hiera" {
            ([Version]$mercurial.DisplayVersion).Build | Should -Be $hgExpectedSoftwareVersion.Build
        }
    }

    Context "Python 3 certificate" {
        It "certifi cacert.pem exists" {
            Test-Path "C:\mozilla-build\python3\Lib\site-packages\certifi\cacert.pem" | Should -Be $true
        }
    }

    Context "Tooltool" {
        It "tooltool cache folder exists" {
            Test-Path "C:\builds\tooltool_cache" | Should -Be $true
        }

        It "TOOLTOOL_CACHE environment variable is set" {
            $ENV:TOOLTOOL_CACHE | Should -Be "C:\builds\tooltool_cache"
        }

        It "tooltool cache grants Everyone full control" {
            ((Get-Acl -Path "C:\builds\tooltool_cache").Access |
            Where-Object { $_.IdentityReference -eq "Everyone" }).FileSystemRights |
            Should -Be "FullControl"
        }
    }

    Context "Install PSUtil" {
        It "psutil __init__.py exists" {
            Test-Path "C:\mozilla-build\python3\Lib\site-packages\psutil\__init__.py" | Should -Be $true
        }
    }
}

Describe "Mozilla Build - Builder" -Skip:(Assert-IsTester) {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
        C:\mozilla-build\python3\python.exe -m pip freeze --all > C:\requirements.txt
    }

    BeforeAll {
        $software = Get-InstalledSoftware
        $mercurial = $software | Where-Object {
            $_.DisplayName -like "Mercurial*"
        }
        $pipPackages = Get-Content C:\requirements.txt
        $variant = $Hiera.'win-worker'.variant
        $win = $Hiera.windows

        $hgExpectedSoftwareVersion = if ($variant.hg.version) { $variant.hg.version } else { $win.hg.version }
        $mozillaBuildExpectedSoftwareVersion = if ($variant.mozilla_build.version) { $variant.mozilla_build.version } else { $win.mozilla_build.version }
        $psutilExpectedSoftwareVersion = if ($variant.mozilla_build.psutil_version) { $variant.mozilla_build.psutil_version } else { $win.mozilla_build.psutil_version }
        $zstandardExpectedSoftwareVersion = if ($variant.mozilla_build.zstandard_version) { $variant.mozilla_build.zstandard_version } else { $win.mozilla_build.zstandard_version }
        $py3PipExpectedSoftwareVersion = if ($variant.mozilla_build.py3_pip_version) { $variant.mozilla_build.py3_pip_version } else { $win.mozilla_build.py3_pip_version }
    }

    Context "Installation" {
        It "Mozilla-Build folder exists" {
            Test-Path "C:\mozilla-build" | Should -Be $true
        }

        It "Mozilla-Build version matches hiera" {
            Get-Content "C:\mozilla-build\VERSION" | Should -Be $mozillaBuildExpectedSoftwareVersion
        }

        It "msys2 sh.exe exists" {
            Test-Path "C:\mozilla-build\msys2\usr\bin\sh.exe" | Should -Be $true
        }
    }

    Context "Pip" {
        It "Certifi is installed" {
            $certifi = ($pipPackages | Where-Object { $_ -match "Certifi" }) -split "=="
            $certifi | Should -Not -Be $null
        }

        It "PSUtil is installed" {
            $psutil = ($pipPackages | Where-Object { $_ -match "PSUtil" }) -split "=="
            $psutil | Should -Not -Be $null
        }

        It "PSUtil version matches hiera" {
            $psutil = ($pipPackages | Where-Object { $_ -match "PSUtil" }) -split "=="
            $psutil[1] | Should -Be $psutilExpectedSoftwareVersion
        }

        It "zstandard is installed" {
            $zstandard = ($pipPackages | Where-Object { $_ -match "zstandard" }) -split "=="
            $zstandard | Should -Not -Be $null
        }

        It "zstandard version matches hiera" {
            $zstandard = ($pipPackages | Where-Object { $_ -match "zstandard" }) -split "=="
            $zstandard[1] | Should -Be $zstandardExpectedSoftwareVersion
        }

        It "pip is installed" {
            $py3pip = ($pipPackages | Where-Object { $_ -match "^pip==" }) -split "=="
            $py3pip | Should -Not -Be $null
        }

        It "pip version matches hiera" {
            $py3pip = ($pipPackages | Where-Object { $_ -match "^pip==" }) -split "=="
            $py3pip[1] | Should -Be $py3PipExpectedSoftwareVersion
        }
    }

    Context "Mercurial" -Skip {
        It "Mercurial is installed" {
            $mercurial.DisplayName | Should -Not -Be $null
        }

        It "Mercurial major version matches hiera" {
            ([Version]$mercurial.DisplayVersion).Major | Should -Be $hgExpectedSoftwareVersion.Major
        }

        It "Mercurial minor version matches hiera" {
            ([Version]$mercurial.DisplayVersion).Minor | Should -Be $hgExpectedSoftwareVersion.Minor
        }

        It "Mercurial build version matches hiera" {
            ([Version]$mercurial.DisplayVersion).Build | Should -Be $hgExpectedSoftwareVersion.Build
        }
    }

    Context "Python 3 certificate" {
        It "certifi cacert.pem exists" {
            Test-Path "C:\mozilla-build\python3\Lib\site-packages\certifi\cacert.pem" | Should -Be $true
        }
    }

    Context "Tooltool" {
        It "tooltool cache folder exists" {
            Test-Path "C:\builds\tooltool_cache" | Should -Be $true
        }

        It "TOOLTOOL_CACHE environment variable is set" {
            $ENV:TOOLTOOL_CACHE | Should -Be "C:\builds\tooltool_cache"
        }

        It "tooltool cache grants Everyone full control" {
            ((Get-Acl -Path "C:\builds\tooltool_cache").Access |
            Where-Object { $_.IdentityReference -eq "Everyone" }).FileSystemRights |
            Should -Be "FullControl"
        }
    }
}
