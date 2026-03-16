## CLEAN-UP Software values should be in Hiera

Describe "Microsoft Tools - Builder" {
    BeforeAll {
        $Directories = Get-WinFactsDirectories
        $software = Get-InstalledSoftware
        $directxsdk = $software | Where-Object {
            $PSItem.DisplayName -eq "Windows SDK DirectX x86 Remote"
        }
        $binscope = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft BinScope 2014"
        }
        $vccx86 = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2015 Redistributable (x86) - 14.0.23918"
        }
        $vccx64 = $software | Where-Object {
            $PSItem.DisplayName -eq "Microsoft Visual C++ 2022 Arm64 Runtime - 14.40.33810"
        }
        $system_env = Get-ChildItem env:
    }
    It "NET Framework Core is installed" {
        Get-WindowsOptionalFeature -Online -FeatureName "NetFx3" | Should -Not -Be $Null
    }
    It "DirectX SDK gets installed" -Skip {
        $directxsdk.DisplayName | Should -Not -Be $Null
    }
    It "DirectX SDK version" -Skip {
        $directxsdk.DisplayVersion | Should -Be "10.1.19041.685"
    }
    It "DirectX Environment Variable is set" {
        $system_env | Where-Object {$PSItem.name -eq "DXSDK_DIR"} | Should -Not -Be $Null
    }
    It "DirectX Environment Variable is set to correct path" {
        $sdkpath = $system_env | Where-Object {$PSItem.name -eq "DXSDK_DIR"}
        $sdkpath.value | Should -Be "$($Directories.custom_win_programfilesx86)\Microsoft DirectX SDK (June 2010)"
    }
    It "Microsoft BinScope 2014 gets installed" {
        $binscope.DisplayName | Should -Not -Be $Null
    }
    It "Microsoft BinScope 2014 version" {
        $binscope.DisplayVersion | Should -Be "7.0.7000.0"
    }
    It "Visual c++ runtime 2015 x86 gets installed" {
        $vccx86.DisplayName | Should -Not -Be $Null
    }
    It "Visual c++ runtime 2015 x86 version" {
        $vccx86.DisplayVersion | Should -Be "14.0.23918.0"
    }
}
