#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'System settings' -Tag IntegrationTests {

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
