#@PDQTestWin
windows_firewall_rule { "puppet - allow lmhosts":
  ensure    => present,
  direction => "inbound",
  action    => "allow",
  service   => "lmhosts",
}