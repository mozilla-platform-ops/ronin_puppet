Describe "IPv6" {
    It "IPv6 is enabled on network adapter" {
        (Get-NetAdapterBinding -ComponentID ms_tcpip6).Enabled | Should -Contain $true
    }
}
