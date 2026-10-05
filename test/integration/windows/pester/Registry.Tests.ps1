#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Registry' -Tag IntegrationTests {
    Context 'Mozilla Maintenance Service' -Skip:(-not $Tester) {
        if (-not $Win10) {
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

    Context 'Windows Update and clipboard' {
        BeforeDiscovery {
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
        }

        It 'sets <Path>\<Name> to <Value>' -ForEach $settings {
            [string](Get-ItemPropertyValue $Path $Name) | Should-BeString $Value
        }
    }

    Context 'Windows settings' {
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
        It 'suppresses the new network dialog' {
            Test-Path 'HKLM:\System\CurrentControlSet\Control\Network\NewNetworkWindowOff' | Should-BeTrue
        }
        It 'does not start SecurityHealth at logon' {
            Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name SecurityHealth -ErrorAction SilentlyContinue |
                Should-BeNull
        }
    }

    Context 'Task storage' {
        if ($TaskDrive -eq 'C:') {
            It 'keeps the cache and page file on C:' {
                Get-ItemPropertyValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' HG_CACHE |
                    Should-BeString 'C:\hg-cache'
                Get-ItemPropertyValue 'HKLM:\SOFTWARE\Mozilla\ronin_puppet' task_drive | Should-BeString 'C:'
                $paging = Get-ItemPropertyValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' PagingFiles
                ($paging -join "`n") | Should-MatchString '(?m)^C:\\pagefile\.sys 8192 8192$'
                ($paging -join "`n") | Should-NotMatchString 'D:\\'
            }
        }
    }
}
