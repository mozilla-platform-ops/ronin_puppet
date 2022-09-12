Describe "Suppress Dialog Boxes" {
    It "NoNewAppAlert exists" {
        Get-ItemPropertyValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "NoNewAppAlert" -ErrorAction "SilentlyContinue" | Should -Be 1
    }
    It "NewNetworkWindowOff exists" {
        Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff" | Should -Be $true
    }
}