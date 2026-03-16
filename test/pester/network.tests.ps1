Describe "Network" {
    BeforeDiscovery {
        $Hiera = $Data.Hiera
    }

    It "IPv6 is disabled" {
        Get-ItemPropertyValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -ErrorAction SilentlyContinue | Should -Be 255
    }
}
