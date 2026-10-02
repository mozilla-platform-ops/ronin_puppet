#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Git and Mercurial' -Tag IntegrationTests {
    BeforeAll {
        $Software = Get-ItemProperty -Path @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        ) -ErrorAction SilentlyContinue
    }

    if (-not $Server25) {
        It 'has Git' {
            ($Software | Where-Object DisplayName -Match '^Git' | Select-Object -First 1).DisplayName |
                Should-MatchString '^Git'
        }
        It 'has Mercurial' { Test-Path 'C:\Program Files\Mercurial\hg.exe' | Should-BeTrue }
    }
}
