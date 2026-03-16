Describe "Azure VM Agent" {
    It "is installed" {
        $agent = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "Windows Azure VM Agent*" }
        $agent | Should -Not -BeNullOrEmpty
    }
}

Describe "Logging" {
    It "NXLog is installed" {
        $nxlog = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "NXLog-CE*" }
        $nxlog | Should -Not -BeNullOrEmpty
    }
}

Describe "7-Zip" {
    It "is installed" {
        $zip = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match "Zip" }
        $zip | Should -Not -BeNullOrEmpty
    }
}

Describe "Git" {
    It "is installed" {
        $git = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match "Git" }
        $git | Should -Not -BeNullOrEmpty
    }
}

Describe "Mercurial" {
    It "hg.exe exists" {
        Test-Path "C:\Program Files\Mercurial\hg.exe" | Should -Be $true
    }
}

Describe "Mozilla Build" {
    It "mozilla-build folder exists" {
        Test-Path "C:\mozilla-build" | Should -Be $true
    }
    It "msys2 sh.exe exists" {
        Test-Path "C:\mozilla-build\msys2\usr\bin\sh.exe" | Should -Be $true
    }
    It "MOZILLABUILD env var is set" {
        $ENV:MOZILLABUILD | Should -Be "C:\mozilla-build"
    }
    It "python3 exists" {
        Test-Path "C:\mozilla-build\python3\python.exe" | Should -Be $true
    }
    It "certifi certificate exists" {
        Test-Path "C:\mozilla-build\python3\Lib\site-packages\certifi\cacert.pem" | Should -Be $true
    }
    It "psutil is installed" {
        Test-Path "C:\mozilla-build\python3\Lib\site-packages\psutil\__init__.py" | Should -Be $true
    }
    It "tooltool cache folder exists" {
        Test-Path "C:\builds\tooltool_cache" | Should -Be $true
    }
    It "mozmake directory exists" {
        Test-Path "C:\mozilla-build\mozmake" | Should -Be $true
    }
    It "mozmake.exe exists" {
        Test-Path "C:\mozilla-build\mozmake\mozmake.exe" | Should -Be $true
    }
    It "tooltool.py exists" {
        Test-Path "C:\mozilla-build\tooltool.py" | Should -Be $true
    }
    It "builds directory exists" {
        Test-Path "C:\builds" | Should -Be $true
    }
}

Describe "Google Auth" {
    It "Google Auth folder exists" {
        Test-Path "$ENV:ProgramData\Google\Auth" | Should -Be $true
    }
}

Describe "DirectX SDK" {
    It "is installed" {
        $dx = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "Microsoft DirectX SDK*" }
        $dx | Should -Not -BeNullOrEmpty
    }
    It "DXSDK_DIR environment variable is set" {
        $ENV:DXSDK_DIR | Should -Not -BeNullOrEmpty
    }
}

Describe "BinScope" {
    It "is installed" {
        $bs = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*BinScope*" }
        $bs | Should -Not -BeNullOrEmpty
    }
}

Describe "VC++ ARM64 Redistributables" {
    It "VC++ 2008 x86 is installed" {
        $vcc = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "Microsoft Visual C++ 2008*x86*" }
        $vcc | Should -Not -BeNullOrEmpty
    }
    It "VC++ 2022 ARM64 is installed" {
        $vcc = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "Microsoft Visual C++ 2022*ARM64*" }
        $vcc | Should -Not -BeNullOrEmpty
    }
}

Describe "Windows Performance Toolkit" {
    It "is installed" {
        $wpt = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*Windows Performance Toolkit*" }
        $wpt | Should -Not -BeNullOrEmpty
    }
}
