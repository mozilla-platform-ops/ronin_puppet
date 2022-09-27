Describe "Firewall" {
    It "ICMP is allowed" {
        (Get-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)").Enabled | Should -BeTrue
    }
}