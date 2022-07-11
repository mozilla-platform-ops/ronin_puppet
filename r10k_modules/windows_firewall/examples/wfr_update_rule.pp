# @PDQTestWin
windows_firewall_rule { "puppet - rule":
  ensure     => present,
  local_port => 1111,
  direction  => "inbound",
  action     => "allow",
  protocol   => "tcp",
}