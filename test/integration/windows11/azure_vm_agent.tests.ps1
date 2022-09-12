BeforeDiscovery {
    . "$env:systemdrive\ronin\test\integration\windows11\Get-InstalledSoftware.ps1"
}

Describe "Windows Azure VM Agent" {
    BeforeAll {
        $Software = Get-InstalledSoftware | Where-Object {
            $PSItem.DisplayName -like "Windows Azure VM Agent*"
        }
    }
    It "Windows Azure VM Agent is installed" {
        $Software.DisplayName | Should -Not -Be $Null
    }
    It "Windows Azure VM Agent is version 2.7.41491.949" {
        $Software.DisplayVersion | Should -Be "2.7.41491.949"
    }
}