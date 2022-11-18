Describe "Network" {
    It "Network Category is private" {
        (Get-NetConnectionProfile).NetworkCategory | Should -Be "Private"
    }
    It "IPv6 is disabled" {
        Get-ItemPropertyValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -ErrorAction SilentlyContinue | Should -Be 255
    }
}
