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
            $validHashes = @(
                '50F79F98DAC192B20DBF73F35C56F0B0C557AB267FF5199D1117CC1180B70785' # LF
                '188AE83F98B8ADB53B0FF3380CE9F8725B945923ACAB8AA22F66363485390FF7' # CRLF
            )
            $validHashes | Should-ContainCollection (Get-FileHash 'C:\Program Files (x86)\nxlog\cert\papertrail-bundle.pem' -Algorithm SHA256).Hash
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
