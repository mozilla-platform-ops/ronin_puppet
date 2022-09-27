Describe "NTP" {
    It "Windows NTP Datacenter" -Skip {
        ((Get-ItemPropertyValue "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer") -split ",")[0] | Should -be "windows.datacenter.ntp"
    }
    It "Windows NTP Non-Datacenter" {
        ((Get-ItemPropertyValue "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer") -split ",")[0] | Should -be "0.pool.ntp.org"
    }
    It "Timezone is Greenwich Standard Time" {
        (Get-TimeZone).ID | Should -Be "Greenwich Standard Time"
    }
}