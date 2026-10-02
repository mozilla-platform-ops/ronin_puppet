BeforeDiscovery { . "$PSScriptRoot/Settings.ps1" }
BeforeAll {
    . "$PSScriptRoot/Settings.ps1"
    $Software = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue
}

Describe 'Installed software' {
    It 'has the configured Azure VM Agent' {
        $agent = $Software | Where-Object DisplayName -Like 'Windows Azure VM Agent*' | Select-Object -First 1
        $agent.DisplayVersion | Should-BeString ((Get-ExpectedValue azure, vm_agent, version).Split('_')[0])
    }
    It 'has 7-Zip 25.00' {
        ($Software | Where-Object DisplayName -Like '*Zip*' | Select-Object -First 1).DisplayVersion |
            Should-MatchString '^25\.00'
    }
    It 'has the Windows Performance Toolkit' {
        ($Software | Where-Object DisplayName -Like 'WPTx64*' | Select-Object -First 1).DisplayName |
            Should-MatchString '^WPTx64'
    }
    It 'has the profiler probe' { Test-Path "$Ronin\mozprofilerprobe.mof" | Should-BeTrue }
    if (-not $Server25) {
        It 'has Git' {
            ($Software | Where-Object DisplayName -Match '^Git' | Select-Object -First 1).DisplayName |
                Should-MatchString '^Git'
        }
        It 'has Mercurial' { Test-Path 'C:\Program Files\Mercurial\hg.exe' | Should-BeTrue }
    }
    if ($Win25) {
        It 'has the Visual C++ runtime for <_>' -ForEach @('x86', 'x64') {
            ($Software | Where-Object DisplayName -Match "^Microsoft Visual C\+\+ 2015-2022 Redistributable \($_\)" |
                Select-Object -First 1).DisplayVersion | Should-MatchString '^14\.\d+\.\d+(?:\.\d+)?$'
        }
    }
    if ($Server -or ($Arm -and -not $Tester)) {
        It 'has the expected .NET 3.5 state' {
            $state = (Get-WindowsOptionalFeature -Online -FeatureName NetFx3).State.ToString()
            if ($Server25 -or $Arm) { $state | Should-MatchString '^Disabled' }
            else { $state | Should-BeString 'Enabled' }
        }
        It 'has the expected DirectX SDK configuration' {
            $path = [Environment]::GetEnvironmentVariable('DXSDK_DIR', 'Machine')
            if ($Server25 -or $Arm) {
                [string]$path | Should-BeEmptyString
                Test-Path "$DxSdk\Include\audiodefs.h" | Should-BeFalse
                if ($Server25) { Test-Path $DxSdk | Should-BeFalse }
            } else {
                $path | Should-BeString $DxSdk
                Test-Path "$DxSdk\Include\audiodefs.h" | Should-BeTrue
            }
        }
        It 'has BinScope 2014' {
            ($Software | Where-Object DisplayName -EQ 'Microsoft BinScope 2014' | Select-Object -First 1).DisplayVersion |
                Should-BeString '7.0.7000.0'
        }
    }
    if ($Arm -and -not $Tester) {
        It 'has <Name>' -ForEach @(
            @{ Name = 'Microsoft Visual C++ 2015 Redistributable (x86) - 14.0.23918'; Version = '^14\.0\.23918(?:\.0)?$' }
            @{ Name = 'Microsoft Visual C++ 2022 Arm64 Runtime - 14.42.34438'; Version = '^14\.42\.34438(?:\.0)?$' }
            @{ Name = 'Microsoft Visual C++ 2022 Redistributable (Arm64) - 14.42.34438'; Version = '^14\.42\.34438(?:\.0)?$' }
        ) {
            ($Software | Where-Object DisplayName -EQ $Name | Select-Object -First 1).DisplayVersion | Should-MatchString $Version
        }
    }
}

Describe 'MozillaBuild and caches' {
    It 'has directory <_>' -ForEach @('C:\mozilla-build', 'C:\builds\tooltool_cache') {
        Test-Path $_ -PathType Container | Should-BeTrue
    }
    It 'has file <_>' -ForEach @(
        'C:\mozilla-build\msys2\usr\bin\sh.exe'
        'C:\mozilla-build\python3\Lib\site-packages\certifi\cacert.pem'
        'C:\mozilla-build\python3\Lib\site-packages\psutil\__init__.py'
    ) { Test-Path $_ | Should-BeTrue }
    It 'has the configured MozillaBuild version' {
        (Get-Content 'C:\mozilla-build\VERSION' -Raw).Trim() | Should-BeString (Get-ExpectedValue mozilla_build, version)
    }
    It 'has the configured <Package> version' -ForEach @(
        @{ Package = 'psutil'; Key = 'psutil_version' }
        @{ Package = 'zstandard'; Key = 'zstandard_version' }
        @{ Package = 'pip'; Key = 'py3_pip_version' }
    ) {
        $output = & 'C:\mozilla-build\python3\python.exe' -m pip show $Package
        $LASTEXITCODE | Should-Be 0
        $version = $output | Select-String '^Version:' | ForEach-Object { $_.ToString().Split(':', 2)[1].Trim() }
        $version | Should-BeString (Get-ExpectedValue mozilla_build, $Key)
    }
    It 'sets TOOLTOOL_CACHE' {
        [Environment]::GetEnvironmentVariable('TOOLTOOL_CACHE', 'Machine') | Should-BeString 'C:\builds\tooltool_cache'
    }
    It 'uses a local Mercurial cache' {
        [Environment]::GetEnvironmentVariable('HG_CACHE', 'Machine') | Should-MatchString '^[CD]:\\hg-cache$'
    }
    if (-not $Win10 -and -not $Server) {
        It 'does not map Y:' { Test-Path 'Y:\' | Should-BeFalse }
    }
    It 'does not configure the removed pip download cache' {
        Get-Content 'C:\ProgramData\pip\pip.ini' -Raw | Should-NotMatchString '(?im)^download-cache\s*='
        [string][Environment]::GetEnvironmentVariable('PIP_DOWNLOAD_CACHE', 'Machine') | Should-BeEmptyString
    }
    It 'does not have <_>' -ForEach @('C:\pip-cache', 'D:\pip-cache') { Test-Path $_ | Should-BeFalse }
}

Describe 'Taskcluster' {
    It 'owns runner.yml as SYSTEM' {
        (Get-Acl 'C:\worker-runner\runner.yml').GetOwner([System.Security.Principal.SecurityIdentifier]).Value |
            Should-BeString 'S-1-5-18'
    }
    if (-not $Server25) {
        It 'has directory <_>' -ForEach @(
            'C:\Windows', 'C:\Program Files\Puppet Labs\Puppet', 'C:\generic-worker', 'C:\worker-runner'
        ) { Test-Path $_ -PathType Container | Should-BeTrue }
        It 'has NSSM' {
            Test-Path "C:\nssm\nssm-$(Get-ExpectedValue nssm, version)\win64\nssm.exe" | Should-BeTrue
        }
        It 'has the worker-runner service' { (Get-Service worker-runner).Name | Should-BeString 'worker-runner' }
        It 'has the configured version of <_>' -ForEach @(
            'C:\generic-worker\generic-worker.exe'
            'C:\worker-runner\start-worker.exe'
            'C:\generic-worker\taskcluster-proxy.exe'
            'C:\generic-worker\livelog.exe'
        ) {
            Test-Path $_ | Should-BeTrue
            $version = & $_ --short-version
            $LASTEXITCODE | Should-Be 0
            $version | Should-BeString (Get-ExpectedValue taskcluster, version)
        }
    }
}

Describe 'Task storage' {
    It 'has the task drive' { Test-Path "$TaskDrive\" -PathType Container | Should-BeTrue }
    if ($Arm) {
        It 'has the ARM temporary drive' { Test-Path 'D:\' -PathType Container | Should-BeTrue }
    }
    if ($TaskDrive -eq 'C:') {
        It 'keeps the cache and page file on C:' {
            Get-ItemPropertyValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' HG_CACHE |
                Should-BeString 'C:\hg-cache'
            Get-ItemPropertyValue 'HKLM:\SOFTWARE\Mozilla\ronin_puppet' task_drive | Should-BeString 'C:'
            $paging = Get-ItemPropertyValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' PagingFiles
            ($paging -join "`n") | Should-MatchString '(?m)^C:\\pagefile\.sys 8192 8192$'
            ($paging -join "`n") | Should-NotMatchString 'D:\\'
        }
        It 'sets the <Setting> directory' -ForEach @(
            @{ Setting = 'tasks'; Directory = 'Users' }
            @{ Setting = 'caches'; Directory = 'caches' }
            @{ Setting = 'downloads'; Directory = 'downloads' }
        ) {
            Get-Content 'C:\worker-runner\runner.yml' -Raw |
                Should-MatchString "(?m)^\s+${Setting}Dir: 'C:\\$Directory'\s*$"
        }
        It 'has the shared Mercurial directory' { Test-Path 'C:\hg-shared' -PathType Container | Should-BeTrue }
    }
    if ($Win25) {
        It 'has the NVMe disk setup script' { Test-Path "$Ronin\configure_nvme_disk.ps1" | Should-BeTrue }
        It 'uses a fixed NTFS task volume' {
            $volume = Get-Volume -DriveLetter $TaskDrive[0]
            $volume.DriveType.ToString() | Should-BeString 'Fixed'
            $volume.FileSystem | Should-BeString 'NTFS'
        }
        It 'selects the Azure VM sizes that require NVMe setup' {
            . "$Ronin\maintainsystem.ps1"
            foreach ($size in @('Standard_D32ads_v7', 'Standard_F8alds_v7', 'Standard_F8ads_v7')) {
                Test-AzureNvmeTemporaryDriveRequired -vmSize $size | Should-BeTrue -Because $size
            }
            foreach ($size in @('Standard_F8s_v2', 'Standard_D8ads_v5', 'Standard_D8alds_v6',
                'Standard_E8ads_v6', 'Standard_NV12ads_A10_v5', 'Standard_E8pds_v5')) {
                Test-AzureNvmeTemporaryDriveRequired -vmSize $size | Should-BeFalse -Because $size
            }
        }
    }
}

Describe 'System settings' {
    BeforeDiscovery {
        $wer = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'
        $fs = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
        $uac = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        $explorer = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
        $registry = @(
            @{ Path = $wer; Name = 'LocalDumps'; Value = '1' }
            @{ Path = $wer; Name = 'DontShowUI'; Value = '1' }
            @{ Path = $fs; Name = 'NtfsDisable8dot3NameCreation'; Value = '1' }
            @{ Path = $fs; Name = 'NtfsDisableLastAccessUpdate'; Value = '2147483649' }
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power'; Name = 'HibernateEnabled'; Value = '0' }
            @{ Path = $explorer; Name = 'NoNewAppAlert'; Value = '1' }
            @{ Path = $explorer; Name = 'DisableNotificationCenter'; Value = '1' }
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications'; Name = 'NoToastApplicationNotification'; Value = '1' }
            @{ Path = $uac; Name = 'EnableLUA'; Value = $(if ($Tester) { '1' } else { '0' }) }
        )
        if ($Tester -or $Server -or $Arm) {
            $registry += @{ Path = $fs; Name = 'LongPathsEnabled'; Value = '1' }
        }
        if (-not $Server) {
            foreach ($entry in @{
                ConsentPromptBehaviorAdmin = '0'; ConsentPromptBehaviorUser = '3'; EnableInstallerDetection = '1'
                EnableVirtualization = '1'; PromptOnSecureDesktop = '0'; ValidateAdminCodeSignatures = '0'; FilterAdministratorToken = '0'
            }.GetEnumerator()) { $registry += @{ Path = $uac; Name = $entry.Key; Value = $entry.Value } }
            if (-not $Win10) {
                foreach ($name in @('ForegroundLockTimeout', 'ForegroundFlashCount')) {
                    $registry += @{ Path = $uac; Name = $name; Value = '0' }
                }
            }
        }
        if ($Arm) {
            $registry += @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'; Name = 'DisabledComponents'; Value = '255' }
        }
        if ($Role -in @('win116424h2azure', 'win116425h2azure')) {
            $registry += @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsAccessMicrophone'; Value = '1' }
            foreach ($name in @('HideEULAPage', 'HideLocalAccountScreen', 'HideOEMRegistrationScreen', 'HideOnlineAccountScreens',
                'HideWirelessSetupInOOBE', 'NetworkLocation', 'OEMAppId', 'ProtectYourPC', 'SkipMachineOOBE', 'SkipUserOOBE')) {
                $registry += @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE'; Name = $name; Value = '1' }
            }
            $registry += @(
                @{ Path = $uac; Name = 'EnableFirstLogonAnimation'; Value = '0' }
                @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'; Name = 'EnableFirstLogonAnimation'; Value = '0' }
                @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE'; Name = 'DisablePrivacyExperience'; Value = '1' }
            )
            foreach ($name in @('DisableWindowsConsumerFeatures', 'DisableSoftLanding', 'DisableCloudOptimizedContent')) {
                $registry += @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = $name; Value = '1' }
            }
        }
        if ($Server25) {
            foreach ($entry in @{
                ProductName = 'Windows Server 2025 Datacenter Azure Edition'; DisplayVersion = '24H2'
                ReleaseId = '2009'; CurrentBuild = '26100'; InstallationType = 'Server'
            }.GetEnumerator()) {
                $registry += @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'; Name = $entry.Key; Value = $entry.Value }
            }
        }
    }
    It 'sets <Path>\<Name> to <Value>' -ForEach $registry {
        [string](Get-ItemPropertyValue -LiteralPath $Path -Name $Name) | Should-BeString $Value
    }
    It 'creates the error dump directory' {
        $folder = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' DumpFolder
        $folder | Should-MatchString '^[A-Z]:\\error-dumps$'
        Test-Path $folder | Should-BeTrue
    }
    It 'uses a private network profile' {
        ((Get-NetConnectionProfile).NetworkCategory -join ',') | Should-MatchString 'Private'
    }
    It 'allows ICMP echo requests' {
        (Get-NetFirewallRule -DisplayName 'ICMP Allow incoming V4 echo request' | Select-Object -First 1).Enabled.ToString() |
            Should-BeString 'True'
    }
    It 'uses UTC' { (Get-TimeZone).Id | Should-BeString 'UTC' }
    It 'uses the high performance power plan' {
        $output = powercfg.exe /getactivescheme
        $LASTEXITCODE | Should-Be 0
        $output | Should-MatchString '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    }
    It 'suppresses the new network dialog' {
        Test-Path 'HKLM:\System\CurrentControlSet\Control\Network\NewNetworkWindowOff' | Should-BeTrue
    }
    It 'does not start SecurityHealth at logon' {
        Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name SecurityHealth -ErrorAction SilentlyContinue |
            Should-BeNull
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

Describe 'Services and scheduled tasks' {
    BeforeDiscovery {
        $disabled = @('puppet', 'DiagTrack')
        if ($Tester) { $disabled += 'WSearch' }
        $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        $settings = @(
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching'; Name = 'SearchOrderConfig'; Value = '0' }
            @{ Path = "$wu\AU"; Name = 'AUOptions'; Value = '1' }
            @{ Path = "$wu\AU"; Name = 'NoAutoUpdate'; Value = '1' }
            @{ Path = $wu; Name = 'DoNotConnectToWindowsUpdateInternetLocations'; Value = '1' }
            @{ Path = $wu; Name = 'DisableWindowsUpdateAccess'; Value = '1' }
        )
        foreach ($name in @('wuauserv', 'WaaSMedicSvc', 'DoSvc')) {
            $settings += @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\$name"; Name = 'Start'; Value = '4' }
        }
        if ($Tester) {
            $settings += @(
                @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\cbdhsvc'; Name = 'Start'; Value = '4' }
                @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\cbdhsvc'; Name = 'UserServiceFlags'; Value = '0' }
                @{ Path = 'HKLM:\SOFTWARE\Microsoft\Clipboard'; Name = 'EnableClipboardHistory'; Value = '0' }
            )
        }
        $tasks = @(
            @{ Name = 'disable_wu'; Script = 'disable_wu_task.ps1' }
            @{ Name = 'at_task_user_logon'; Script = 'at_task_user_logon.ps1' }
            @{ Name = 'maintain_system'; Script = 'maintainsystem.ps1' }
        )
        if ($Tester) { $tasks += @{ Name = 'kill_remote_clipboard'; Script = 'kill_local_clipboard.ps1' } }
    }
    It 'stops and disables <_>' -ForEach $disabled {
        $service = Get-CimInstance Win32_Service -Filter "Name='$_'"
        $service.State | Should-BeString 'Stopped'
        $service.StartMode | Should-BeString 'Disabled'
    }
    It 'sets <Path>\<Name> to <Value>' -ForEach $settings {
        [string](Get-ItemPropertyValue $Path $Name) | Should-BeString $Value
    }
    It 'runs <Name> as SYSTEM' -ForEach $tasks {
        $task = Get-ScheduledTask -TaskName $Name | Select-Object -First 1
        $task.Settings.Enabled | Should-BeTrue
        $task.Principal.UserId | Should-BeString 'SYSTEM'
        $action = $task.Actions | Select-Object -First 1
        $action.Execute | Should-MatchString 'powershell\.exe$'
        $action.Arguments | Should-MatchString ([regex]::Escape("$Ronin\$Script"))
    }
    if ($Tester) {
        It 'has <_>' -ForEach @('xperf_kernel_start.ps1', 'xperf_kernel_stop.ps1', 'xperf_register_tasks.ps1') {
            Test-Path "$Ronin\$_" | Should-BeTrue
        }
        It 'runs the <Name> script' -ForEach @(
            @{ Name = 'xperf_kernel_trace_start'; Script = 'xperf_kernel_start.ps1' }
            @{ Name = 'xperf_kernel_trace_stop'; Script = 'xperf_kernel_stop.ps1' }
        ) {
            $action = (Get-ScheduledTask -TaskName $Name | Select-Object -First 1).Actions | Select-Object -First 1
            $action.Execute | Should-MatchString 'powershell\.exe$'
            $action.Arguments | Should-MatchString ([regex]::Escape("$Ronin\$Script"))
        }
    }
    It 'has NXLog 2.10.2150' {
        ($Software | Where-Object DisplayName -EQ 'NXLog-CE' | Select-Object -First 1).DisplayVersion |
            Should-MatchString '^2\.10\.2150(?:\.\d+)?$'
    }
    It 'has the NXLog configuration and certificate bundle' {
        Test-Path 'C:\Program Files (x86)\nxlog\conf\nxlog.conf' | Should-BeTrue
        (Get-FileHash 'C:\Program Files (x86)\nxlog\cert\papertrail-bundle.pem' -Algorithm SHA256).Hash |
            Should-BeString 'AE31ECB3C6E9FF3154CB7A55F017090448F88482F0E94AC927C0C67A1F33B9CF'
    }
    It 'runs NXLog' { (Get-CimInstance Win32_Service -Filter "Name='nxlog'").State | Should-BeString 'Running' }
}

Describe 'Mozilla Maintenance Service' -Skip:(-not $Tester) {
    It 'is installed' {
        ($Software | Where-Object DisplayName -EQ 'Mozilla Maintenance Service' | Select-Object -First 1).DisplayName |
            Should-BeString 'Mozilla Maintenance Service'
    }
    if (-not $Win10) {
        It 'has the service' { (Get-Service MozillaMaintenance).Name | Should-BeString 'MozillaMaintenance' }
        It 'trusts the Mozilla test certificate <_>' -ForEach @(
            'FA056CEBEFF3B1D0500A1FB37C2BD2F9CE4FB5D8'
            'EA66A61D6C382C8D1CA8C345EEB7D4DF4AFBEF18'
            'A13DC11A11F27619734BD4B73F2649FFDA3E6230'
        ) {
            (Get-ChildItem Cert:\LocalMachine\Root | Where-Object Thumbprint -EQ $_).Issuer | Should-BeString 'CN=Mozilla Fake CA'
        }
        It 'registers maintenance signing certificate <Index>' -ForEach @(
            @{ Index = 0; Issuer = 'DigiCert Trusted G4 Code Signing RSA4096 SHA384 2021 CA1'; Name = 'Mozilla Corporation' }
            @{ Index = 1; Issuer = 'Mozilla Fake CA'; Name = 'Mozilla Fake SPC' }
            @{ Index = 2; Issuer = 'DigiCert SHA2 Assured ID Code Signing CA'; Name = 'Mozilla Corporation' }
        ) {
            $key = "HKLM:\SOFTWARE\Mozilla\MaintenanceService\3932ecacee736d366d6436db0f55bce4\$Index"
            Get-ItemPropertyValue $key issuer | Should-BeString $Issuer
            Get-ItemPropertyValue $key name | Should-BeString $Name
        }
    }
}

Describe 'Drivers' {
    if ($Tester -or $Server25) {
        It 'caches the GPU installer' {
            $installer = "C:\Windows\Temp\$(Get-ExpectedValue gpu, name).exe"
            Test-Path $installer | Should-BeTrue
            if ($Win25) { (Get-Item $installer).Length | Should-BeGreaterThan 100000000 }
        }
    }
    if (($Win10 -or $Server25) -and $env:WORKER_POOL_ID -like '*gpu*') {
        It 'runs the configured NVIDIA A10-8Q driver' {
            $version = (Get-ExpectedValue gpu, name).Split('_')[0]
            $output = nvidia-smi.exe --query-gpu=name,driver_version --format=csv,noheader
            $LASTEXITCODE | Should-Be 0
            $output | Should-MatchString "^NVIDIA A10-8Q,\s*$([regex]::Escape($version))\s*$"
        }
    }
    if ($Tester -and -not $Arm) {
        It 'installs Virtual Audio Cable' {
            Test-Path "C:\VAC\$(Get-ExpectedValue vac, package_dir)" -PathType Container | Should-BeTrue
            $name = Get-ExpectedValue vac, service_name
            (Get-CimInstance Win32_SystemDriver -Filter "Name='$name'").Name | Should-BeString $name
            $device = Get-ExpectedValue vac, pnp_device_name
            (Get-PnpDevice -Class MEDIA | Where-Object FriendlyName -EQ $device | Select-Object -First 1).FriendlyName |
                Should-BeString $device
        }
    }
    if ($Win25) {
        It 'uses a cached NVIDIA installer without network access' {
            # Keep Puppet's Facter overrides in a child process, as in the old test.
            & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PSScriptRoot/OfflineNvidia.ps1"
            $LASTEXITCODE | Should-Be 0
        }
    }
}
