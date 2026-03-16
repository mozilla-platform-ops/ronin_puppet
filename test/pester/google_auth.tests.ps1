Describe "Google Auth" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }
    BeforeAll {
        $Directories = Get-WinFactsDirectories
    }
    It "Google Folder Exists" {
        Test-Path "$($Directories.custom_win_programdata)\Google" | Should -Be $True
    }
    It "Google Auth Folder" {
        Test-Path "$($Directories.custom_win_programdata)\Google\Auth" | Should -Be $True
    }
}
