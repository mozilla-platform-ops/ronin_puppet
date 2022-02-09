# @PDQTestWin
windows_firewall_rule { "puppet - rule":
  ensure     => present,
  local_port => 9999,
  direction  => "inbound",
  action     => "allow",
  protocol   => "tcp",
}