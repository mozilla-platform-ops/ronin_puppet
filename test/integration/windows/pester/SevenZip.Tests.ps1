#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'SevenZip' -Tag IntegrationTests {
    BeforeAll {
        $Software = Get-ItemProperty -Path @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        ) -ErrorAction SilentlyContinue
    }

    It 'has 7-Zip 25.00' {
        ($Software | Where-Object DisplayName -Like '*Zip*' | Select-Object -First 1).DisplayVersion |
            Should-MatchString '^25\.00'
    }
}
