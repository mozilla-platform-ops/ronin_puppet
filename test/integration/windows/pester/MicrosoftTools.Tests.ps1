#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Microsoft tools' -Tag IntegrationTests {
    BeforeAll {
        $Software = Get-ItemProperty -Path @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        ) -ErrorAction SilentlyContinue
    }

    It 'has the Windows Performance Toolkit' {
        ($Software | Where-Object DisplayName -Like 'WPTx64*' | Select-Object -First 1).DisplayName |
            Should-MatchString '^WPTx64'
    }
    It 'has the profiler probe' { Test-Path "$Ronin\mozprofilerprobe.mof" | Should-BeTrue }
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
