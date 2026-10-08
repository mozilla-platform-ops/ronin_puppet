#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Files' -Tag IntegrationTests {
    Context 'Microsoft tools' {
        It 'has the profiler probe' { Test-Path "$Ronin\mozprofilerprobe.mof" | Should-BeTrue }
    }

    Context 'MozillaBuild and caches' {
        It 'has directory <_>' -ForEach @('C:\mozilla-build', 'C:\builds\tooltool_cache') {
            Test-Path $_ -PathType Container | Should-BeTrue
        }
        It 'has file <_>' -ForEach @(
            'C:\mozilla-build\msys2\usr\bin\sh.exe'
            'C:\mozilla-build\python3\Lib\site-packages\certifi\cacert.pem'
            'C:\mozilla-build\python3\Lib\site-packages\psutil\__init__.py'
        ) { Test-Path $_ | Should-BeTrue }
        It 'does not have <_>' -ForEach @('C:\pip-cache', 'D:\pip-cache') { Test-Path $_ | Should-BeFalse }
        if (-not $Win10 -and -not $Server) {
            It 'does not map Y:' { Test-Path 'Y:\' | Should-BeFalse }
        }
    }

    Context 'GPU and audio drivers' {
        if ($Tester -or $Server25) {
            It 'caches the GPU installer' {
                $installer = "C:\RoninPackages\$(Get-HieraValue 'windows.gpu.name').exe"
                Test-Path $installer | Should-BeTrue
                if ($Win25) { (Get-Item $installer).Length | Should-BeGreaterThan 100000000 }
            }
        }
    }

    Context 'Worker scripts and logging' {
        if ($Tester) {
            It 'has <_>' -ForEach @('xperf_kernel_start.ps1', 'xperf_kernel_stop.ps1', 'xperf_register_tasks.ps1') {
                Test-Path "$Ronin\$_" | Should-BeTrue
            }
        }
        It 'has the NXLog configuration and certificate bundle' {
            Test-Path 'C:\Program Files (x86)\nxlog\conf\nxlog.conf' | Should-BeTrue
            (Get-FileHash 'C:\Program Files (x86)\nxlog\cert\papertrail-bundle.pem' -Algorithm SHA256).Hash |
                Should-BeString 'AE31ECB3C6E9FF3154CB7A55F017090448F88482F0E94AC927C0C67A1F33B9CF'
        }
    }

    Context 'Windows settings' {
        It 'creates the error dump directory' {
            $folder = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' DumpFolder
            $folder | Should-MatchString '^[A-Z]:\\error-dumps$'
            Test-Path $folder | Should-BeTrue
        }
        if ($Server25) {
            It 'has the task user init script' { Test-Path 'C:\generic-worker\task-user-init.cmd' -PathType Leaf | Should-BeTrue }
        }
        if (-not $Tester) {
            It 'has directory <_>' -ForEach @('C:\ProgramData\Google', 'C:\ProgramData\Google\Auth') {
                Test-Path $_ -PathType Container | Should-BeTrue
            }
        }
    }

    Context 'Taskcluster' {
        It 'owns runner.yml as SYSTEM' {
            (Get-Acl 'C:\worker-runner\runner.yml').GetOwner([System.Security.Principal.SecurityIdentifier]).Value |
                Should-BeString 'S-1-5-18'
        }
        if (-not $Server25) {
            It 'has directory <_>' -ForEach @(
                'C:\Windows', 'C:\Program Files\Puppet Labs\Puppet', 'C:\generic-worker', 'C:\worker-runner'
            ) { Test-Path $_ -PathType Container | Should-BeTrue }
        }
    }

    Context 'Task storage' {
        It 'has the task drive' { Test-Path "$TaskDrive\" -PathType Container | Should-BeTrue }
        if ($Arm) {
            It 'has the ARM temporary drive' { Test-Path 'D:\' -PathType Container | Should-BeTrue }
        }
        if ($TaskDrive -eq 'C:') {
            # The provisioner's work-volume check verifies the runtime paths.
            if ((Get-HieraValue 'windows_work_volume' -Default 'false') -ne $true) {
                It 'sets the <Setting> directory' -ForEach @(
                    @{ Setting = 'tasks'; Directory = 'Users' }
                    @{ Setting = 'caches'; Directory = 'caches' }
                    @{ Setting = 'downloads'; Directory = 'downloads' }
                ) {
                    Get-Content 'C:\worker-runner\runner.yml' -Raw |
                        Should-MatchString "(?m)^\s+${Setting}Dir: 'C:\\$Directory'\s*$"
                }
            }
            It 'has the shared Mercurial directory' { Test-Path 'C:\hg-shared' -PathType Container | Should-BeTrue }
        }
        if ($Win25) {
            It 'has the NVMe disk setup script' { Test-Path "$Ronin\configure_nvme_disk.ps1" | Should-BeTrue }
        }
    }
}
