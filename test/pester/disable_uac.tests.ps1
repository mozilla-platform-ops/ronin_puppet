Describe "Disable UAC" {
    Context "Disable User Account Control" {
        It "UAC is disabled" {
            Get-ItemPropertyValue HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name "EnableLUA" | Should -Be 0
        }
    }
}
