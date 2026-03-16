## CLEAN-UP Software versions should be in Hiera

Describe "Microsoft DirectX SDK (June 2010)" {
    BeforeAll {
        $Directories = Get-WinFactsDirectories
        $system_env = Get-ChildItem env:
    }
    It "DirectX SDK Exists" {
        Test-Path "${ENV:ProgramFiles(x86)}\Microsoft DirectX SDK (June 2010)" | Should -Be $true
    }
    It "DirectX Environment Variable is set" {
        $system_env | Where-Object {$PSItem.name -eq "DXSDK_DIR"} | Should -Not -Be $Null
    }
    It "DirectX Environment Variable is set to correct path" {
        $sdkpath = $system_env | Where-Object {$PSItem.name -eq "DXSDK_DIR"}
        $sdkpath.value | Should -Be "$($Directories.custom_win_programfilesx86)\Microsoft DirectX SDK (June 2010)"
    }
}
