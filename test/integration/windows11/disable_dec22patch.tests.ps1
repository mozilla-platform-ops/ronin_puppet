Describe "Disable Dec22 Patch" {
    It "XPSAllowedTypes should exist" {
        Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\.NETFramework\Windows Presentation Foundation\XPSAllowedTypes\'| Should -Not -Be $null
    }
    It "DisableDec2022Patch should exist" {
        Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\.NETFramework\Windows Presentation Foundation\XPSAllowedTypes" -Name "DisableDec2022Patch" | Should -Be '*'
    }
}
