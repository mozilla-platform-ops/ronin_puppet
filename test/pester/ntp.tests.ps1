Describe "NTP" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    It "Windows NTP Datacenter" -Skip {
        ((Get-ItemPropertyValue "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer") -split ",")[0] | Should -be "windows.datacenter.ntp"
    }
    It "Windows NTP Non-Datacenter" {
        ((Get-ItemPropertyValue "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer") -split ",")[0] | Should -be "time.windows.com"
    }
    It "Timezone is UTC" {
        (Get-TimeZone).ID | Should -Be "UTC"
    }
}
