# @PDQTestWin
resources { "windows_firewall_rule":
  purge => true,
}

windows_firewall_rule { "puppet - allow all":
  ensure     => present,
  direction  => "inbound",
  action     => "allow",
  protocol   => "tcp",
  local_port => "any",
}