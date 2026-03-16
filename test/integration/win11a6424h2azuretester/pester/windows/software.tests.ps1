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
}

Describe "Mozilla Maintenance Service" {
    It "is installed" {
        $mms = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -eq "Mozilla Maintenance Service" }
        $mms | Should -Not -BeNullOrEmpty
    }
    It "Windows service exists" {
        Get-Service "MozillaMaintenance" | Should -Not -Be $null
    }
    It "Registry key exists" {
        Test-Path "HKLM:\SOFTWARE\Mozilla\MaintenanceService\3932ecacee736d366d6436db0f55bce4" | Should -Be $true
    }
}

Describe "Windows Performance Toolkit" {
    It "is installed" {
        $wpt = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*Windows Performance Toolkit*" }
        $wpt | Should -Not -BeNullOrEmpty
    }
}
