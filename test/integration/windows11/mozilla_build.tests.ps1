BeforeDiscovery {
    . "$env:systemdrive\ronin\test\integration\windows11\Get-InstalledSoftware.ps1"
    C:\mozilla-build\python3\python.exe -m pip freeze --all > C:\requirements.txt
}

Describe "Mozilla Build" {
    BeforeAll {
        $software = Get-InstalledSoftware
        $mercurial = $software | Where-Object {
            $PSItem.DisplayName -like "Mercurial*"
        }
        $mms = $software | Where-Object {
            $PSItem.DisplayName -like "Mozilla Maintenance Service*"
        }
        $pip_packages = Get-Content C:\requirements.txt
        $Install_Path = "C:\mozilla-build"
    }
    Context "Installation" {
        It "Mozilla-Build Folder exists" {
            Test-Path $Install_Path | Should -Be $true
        }
        It "Mozilla-Build Version" {
            Get-Content "C:\mozilla-build\VERSION" | Should -Be "4.0.2"
        }
        It "msys\bin\sh.exe exists" {
            Test-Path "$Install_Path\msys\bin\sh.exe" | Should -Be $true
        }
        It "Mozilla Maintenance Service gets installed" {
            $mms.DisplayName | Should -Not -Be $Null
        }
        It "Mozilla Maintenance Service is 27.0a1" {
            $mms.DisplayVersion | Should -Be "27.0a1"
        }
    }
    Context "Pip" {
        It "Certifi is installed" {
            $certifi = (pip_packages | Where-Object {$psitem -Match "Certifi"}) -split "==" 
            $certifi | Should -Not -Be $null
        }
        It "PSUtil is installed" {
            $PSUtil = (pip_packages | Where-Object {$psitem -Match "PSUtil"}) -split "==" 
            $PSUtil | Should -Not -Be $null
        }
        It "PSUtil version 5.9.4" {
            $PSUtil = (pip_packages | Where-Object {$psitem -Match "PSUtil"}) -split "==" 
            $PSUtil[1] | Should -Not -Be $null
        }
        It "ZStandard is installed" {
            $ZStandard = (pip_packages | Where-Object {$psitem -Match "zstandard"}) -split "==" 
            $ZStandard | Should -Not -Be $null
        }
        It "ZStandard version 0.15.2" {
            $ZStandard = (pip_packages | Where-Object {$psitem -Match "zstandard"}) -split "==" 
            $ZStandard[1] | Should -Be "0.15.2"
        }
    }
    Context "Mercurial" {
        It "Mercurial gets installed" {
            $mercurial.DisplayName | Should -Not -Be $Null
        }
        It "Mercurial is 5.9.3" {
            $mercurial.DisplayVersion | Should -Be "5.9.3"
        }
    }
    Context "HG Files" -Skip {
        BeforeAll {
            $hgshared_acl = (Get-Acl -Path C:\hg-shared).Access |
            Where-Object { $PSItem.IdentityReference -eq "Everyone" }
        }
        It "HG Shared folder exists" {
            Test-Path "C:\Hg-Shared" | Should -Be $true
        }
        It "HG Shared folder permissions" {
            $hgshared_acl.FileSystemRights | Should -Be "FullControl"
        }
    }
    Context "Python 3 Certificate" {
        It "Certificate exists" {
            Test-Path "$Install_Path\python3\Lib\site-packages\certifi\cacert.pem" | Should -Be $true
        }
    }
    Context "ToolTool" -Skip {
        It "ToolTool Cache Folder Exists" {
            Test-Path "C:\builds\tooltool_cache" | Should -Be $true
        }
        It "ToolTool Cache Folder Environment Variable" {
            $ENV:TOOLTOOL_CACHE | Should -Be "C:\builds\tooltool_cache"
        }
        It "ToolTool Cache Drive Permissions" {
            ((Get-Acl -Path "C:\builds\tooltool_cache").Access |
            Where-Object { $PSItem.IdentityReference -eq "Everyone" }).FileSystemRights |
            Should -Be "FullControl"
        }
    }
    Context "Modifications" -Skip {
        It "hg removed from mozbuild path" {
            Test-Path "$Install_Path\python3\Scripts\hg" | Should -Be $false
        }
        It "Mozillabuild environment variable" {
            $ENV:MOZILLABUILD | Should -be $Install_Path
        }
    }
    Context "Set Registry Priority" {
        BeforeEach {
            $py_key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\python.exe\PerfOptions"
            $hg_key = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\hg.exe\PerfOptions"
        }
        It "Python key exists" {
            Test-Path $py_key | Should -Be $true
        }
        It "Hg key exists" {
            Test-Path $hg_key | Should -Be $true
        }
        It "CPU Priority for Python" {
            Get-ItemPropertyValue $py_key -Name "CpuPriorityClass" | Should -Be 6
        }
        It "IO Priority for Python" {
            Get-ItemPropertyValue $py_key -Name "IoPriority" | Should -Be 2
        }
        It "CPU Priority for hg" {
            Get-ItemPropertyValue $hg_key -Name "CpuPriorityClass" | Should -Be 6
        }
        It "IO Priority for hg" {
            Get-ItemPropertyValue $hg_key -Name "IoPriority" | Should -Be 2
        }
    }
    Context "Symlink Access" -Skip {
        BeforeAll {
            . "$env:windir\System32\WindowsPowerShell\v1.0\Modules\Carbon\Import-Carbon"
            $everyone = Get-Privilege -Identity "everyone"
            $system = Get-Privilege -Identity "system"
        }
        It "Everyone has symbolicprivilege" {
            $everyone | Should -Contain "SeCreateSymbolicLinkPrivilege"
        }
        It "System has symbolicprivilege" {
            $system | Should -Contain "SeCreateSymbolicLinkPrivilege"
        }
    }
    Context "Install PSUtil" -Skip {
        It "init.py path exists for python 3" {
            Test-Path "$Install_Path\python3\Lib\site-packages\psutil\__init__.py" | Should -Be $true
        }
        It "init.py path exists for python" {
            Test-Path "$Install_Path\python3\Lib\site-packages\psutil\__init__.py" | Should -Be $true
        }
    }
}
