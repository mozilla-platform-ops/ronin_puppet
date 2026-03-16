<#
HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\OOBE
#>

Describe "OOBE Registry values are set" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    It "HideEULAPage is set to 1" {
        Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name "HideEULAPage" -ErrorAction "SilentlyContinue" | Should -Be 1
    }
    It "HideLocalAccountScreen is set to 1" {
        Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name "HideLocalAccountScreen" -ErrorAction "SilentlyContinue" | Should -Be 1
    }
    It "HideOEMRegistrationScreen is set to 1" {
        Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name "HideOEMRegistrationScreen" -ErrorAction "SilentlyContinue" | Should -Be 1
    }
    It "HideOnlineAccountScreens is set to 1" {
        Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name "HideOnlineAccountScreens" -ErrorAction "SilentlyContinue" | Should -Be 1
    }
    It "HideWirelessSetupInOOBE is set to 1" {
        Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name "HideWirelessSetupInOOBE" -ErrorAction "SilentlyContinue" | Should -Be 1
    }
    It "NetworkLocation is set to 1" {
        Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name "NetworkLocation" -ErrorAction "SilentlyContinue" | Should -Be 1
    }
    It "OEMAppId is set to 1" {
        Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name "OEMAppId" -ErrorAction "SilentlyContinue" | Should -Be 1
    }
    It "ProtectYourPC is set to 1" {
        Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name "ProtectYourPC" -ErrorAction "SilentlyContinue" | Should -Be 1
    }
    It "SkipMachineOOBE is set to 1" {
        Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name "SkipMachineOOBE" -ErrorAction "SilentlyContinue" | Should -Be 1
    }
    It "SkipUserOOBE is set to 1" {
        Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" -Name "SkipUserOOBE" -ErrorAction "SilentlyContinue" | Should -Be 1
    }
}
