Describe "Error reporting" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    BeforeAll {
        $DumpPath = "C:\error-dumps"
    }
    It "Error dump folder exists" {
        Test-Path $DumpPath | Should -Be $True
    }
    It "Error dumpfolder registry exists" {
        Get-ItemPropertyValue "HKLM:\Software\Microsoft\Windows\Windows Error Reporting" -Name "DumpFolder" -ErrorAction SilentlyContinue | Should -Be $DumpPath
    }
    It "Error localdumps registry exists" {
        Get-ItemPropertyValue "HKLM:\Software\Microsoft\Windows\Windows Error Reporting" -Name "LocalDumps" -ErrorAction SilentlyContinue | Should -Be 1
    }
    It "Error DontShowUI registry exists" {
        Get-ItemPropertyValue "HKLM:\Software\Microsoft\Windows\Windows Error Reporting" -Name "DontShowUI" -ErrorAction SilentlyContinue | Should -Be 1
    }
}
