#@PDQTestWin
windows_firewall_rule { "puppet - allow icmp 1":
  ensure    => present,
  direction => "inbound",
  action    => "allow",
  protocol  => "icmpv4",
  icmp_type => "1",
}

windows_firewall_rule { "puppet - allow icmp 2":
  ensure    => present,
  direction => "inbound",
  action    => "allow",
  protocol  => "icmpv4",
  icmp_type => "2:1",
}

windows_firewall_rule { "puppet - allow icmp 3":
  ensure    => present,
  direction => "inbound",
  action    => "allow",
  protocol  => "icmpv4",
  icmp_type => "any",
}