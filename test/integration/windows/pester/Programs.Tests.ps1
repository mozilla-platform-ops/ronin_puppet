#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Programs' -Tag IntegrationTests {
    BeforeAll {
        $Software = Get-ItemProperty -Path @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        ) -ErrorAction SilentlyContinue
    }

    Context 'Azure VM Agent' {
        It 'has the configured Azure VM Agent' {
            $agent = $Software | Where-Object DisplayName -Like 'Windows Azure VM Agent*' | Select-Object -First 1
            $agent.DisplayVersion | Should-BeString ((Get-HieraValue 'windows.azure.vm_agent.version').Split('_')[0])
        }
    }

    Context 'Microsoft tools' {
        It 'has the Windows Performance Toolkit' {
            ($Software | Where-Object DisplayName -Like 'WPTx64*' | Select-Object -First 1).DisplayName |
                Should-MatchString '^WPTx64'
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

    Context 'MozillaBuild and caches' {
        It 'has the configured MozillaBuild version' {
            (Get-Content 'C:\mozilla-build\VERSION' -Raw).Trim() | Should-BeString (Get-HieraValue 'windows.mozilla_build.version')
        }
        It 'has the configured <Package> version' -ForEach @(
            @{ Package = 'psutil'; Key = 'psutil_version' }
            @{ Package = 'zstandard'; Key = 'zstandard_version' }
            @{ Package = 'pip'; Key = 'py3_pip_version' }
        ) {
            $output = & 'C:\mozilla-build\python3\python.exe' -m pip show $Package
            $LASTEXITCODE | Should-Be 0
            $version = $output | Select-String '^Version:' | ForEach-Object { $_.ToString().Split(':', 2)[1].Trim() }
            $version | Should-BeString (Get-HieraValue "windows.mozilla_build.$Key")
        }
    }

    Context 'Mozilla Maintenance Service' -Skip:(-not $Tester) {
        It 'is installed' {
            ($Software | Where-Object DisplayName -EQ 'Mozilla Maintenance Service' | Select-Object -First 1).DisplayName |
                Should-BeString 'Mozilla Maintenance Service'
        }
    }

    Context 'NXLog' {
        It 'has NXLog 2.10.2150' {
            ($Software | Where-Object DisplayName -EQ 'NXLog-CE' | Select-Object -First 1).DisplayVersion |
                Should-MatchString '^2\.10\.2150(?:\.\d+)?$'
        }
    }

    Context '7-Zip' {
        It 'has 7-Zip 25.00' {
            ($Software | Where-Object DisplayName -Like '*Zip*' | Select-Object -First 1).DisplayVersion |
                Should-MatchString '^25\.00'
        }
    }

    Context 'Taskcluster' {
        if (-not $Server25) {
            It 'has NSSM' {
                Test-Path "C:\nssm\nssm-$(Get-HieraValue 'windows.nssm.version')\win64\nssm.exe" | Should-BeTrue
            }
            It 'has the configured version of <_>' -ForEach @(
                'C:\generic-worker\generic-worker.exe'
                'C:\worker-runner\start-worker.exe'
                'C:\generic-worker\taskcluster-proxy.exe'
                'C:\generic-worker\livelog.exe'
            ) {
                Test-Path $_ | Should-BeTrue
                # ARM binaries write startup diagnostics to stderr. Redirect before PowerShell 5.1 sees them.
                $version = cmd.exe /c "`"$_`" --short-version 2>nul"
                $LASTEXITCODE | Should-Be 0
                $version | Should-BeString (Get-HieraValue 'win-worker.variant.taskcluster.version', 'windows.taskcluster.version')
            }
        }
    }

    Context 'Git and Mercurial' {
        if (-not $Server25) {
            It 'has Git' {
                ($Software | Where-Object DisplayName -Match '^Git' | Select-Object -First 1).DisplayName |
                    Should-MatchString '^Git'
            }
            It 'has Mercurial' { Test-Path 'C:\Program Files\Mercurial\hg.exe' | Should-BeTrue }
        }
    }

    Context 'Windows SDK' -Skip:($Role -notin @('win116424h2azure', 'win116425h2azure')) {
        It 'installs <_> version 10.1.22621.5040' -ForEach @(
            'Application Verifier x64 External Package (DesktopEditions)'
            'Application Verifier x64 External Package (OnecoreUAP)'
            'Kits Configuration Installer'
            'MSI Development Tools'
            'SDK ARM Additions'
            'SDK ARM Redistributables'
            'SDK Debuggers'
            'Universal CRT Extension SDK'
            'Universal CRT Headers Libraries and Sources'
            'Universal CRT Redistributable'
            'Universal CRT Tools x64'
            'Universal CRT Tools x86'
            'Universal General MIDI DLS Extension SDK'
            'WinAppDeploy'
            'Windows App Certification Kit Native Components'
            'Windows App Certification Kit SupportedApiList x86'
            'Windows App Certification Kit x64'
            'Windows App Certification Kit x64 (OnecoreUAP)'
            'Windows Desktop Extension SDK'
            'Windows Desktop Extension SDK Contracts'
            'Windows IoT Extension SDK'
            'Windows IoT Extension SDK Contracts'
            'Windows IP Over USB'
            'Windows Mobile Extension SDK'
            'Windows Mobile Extension SDK Contracts'
            'Windows SDK'
            'Windows SDK ARM Desktop Tools'
            'Windows SDK Desktop Headers arm'
            'Windows SDK Desktop Headers arm64'
            'Windows SDK Desktop Headers x64'
            'Windows SDK Desktop Headers x86'
            'Windows SDK Desktop Libs arm'
            'Windows SDK Desktop Libs arm64'
            'Windows SDK Desktop Libs x64'
            'Windows SDK Desktop Libs x86'
            'Windows SDK Desktop Tools arm64'
            'Windows SDK Desktop Tools x64'
            'Windows SDK Desktop Tools x86'
            'Windows SDK DirectX x64 Remote'
            'Windows SDK DirectX x86 Remote'
            'Windows SDK EULA'
            'Windows SDK Facade Windows WinMD Versioned'
            'Windows SDK for Windows Store Apps'
            'Windows SDK for Windows Store Apps Contracts'
            'Windows SDK for Windows Store Apps DirectX x86 Remote'
            'Windows SDK for Windows Store Apps Headers'
            'Windows SDK for Windows Store Apps Libs'
            'Windows SDK for Windows Store Apps Metadata'
            'Windows SDK for Windows Store Apps Tools'
            'Windows SDK for Windows Store Managed Apps Libs'
            'Windows SDK Modern Non-Versioned Developer Tools'
            'Windows SDK Modern Versioned Developer Tools'
            'Windows SDK Redistributables'
            'Windows SDK Signing Tools'
            'Windows Team Extension SDK'
            'Windows Team Extension SDK Contracts'
            'WinRT Intellisense Desktop - en-us'
            'WinRT Intellisense Desktop - Other Languages'
            'WinRT Intellisense IoT - en-us'
            'WinRT Intellisense IoT - Other Languages'
            'WinRT Intellisense Mobile - en-us'
            'WinRT Intellisense PPI - en-us'
            'WinRT Intellisense PPI - Other Languages'
            'WinRT Intellisense UAP - en-us'
            'WinRT Intellisense UAP - Other Languages'
            'WPT Redistributables'
            'WPTx64 (DesktopEditions)'
            'WPTx64 (OnecoreUAP)'
        ) {
            ($Software | Where-Object DisplayName -EQ $_ | Select-Object -First 1).DisplayVersion |
                Should-BeString '10.1.22621.5040'
        }
    }
}
