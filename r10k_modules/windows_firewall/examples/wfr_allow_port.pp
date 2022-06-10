#@PDQTestWin
windows_firewall_rule { "puppet - allow ports 1000-2000":
  ensure     => present,
  direction  => "inbound",
  action     => "allow",
  protocol   => "tcp",
  local_port => "1000-2000",
}

windows_firewall_rule { "puppet - allow port rpc":
  ensure     => present,
  direction  => "inbound",
  action     => "allow",
  protocol   => "tcp",
  local_port => "RPC",
}

windows_firewall_rule { "puppet - allow port rpcemap":
  ensure     => present,
  direction  => "inbound",
  action     => "allow",
  protocol   => "tcp",
  local_port => "RPCEPMap",
}

windows_firewall_rule { "puppet - allow port iphttps - in":
  ensure     => present,
  direction  => "inbound",
  action     => "allow",
  protocol   => "tcp",
  local_port => "IPHTTPSIn",
}

windows_firewall_rule { "puppet - allow port iphttps - out":
  ensure      => present,
  direction   => "outbound",
  action      => "allow",
  protocol    => "tcp",
  remote_port => "IPHTTPSOut",
}

windows_firewall_rule { "puppet - open port in specific profiles":
  ensure         => present,
  direction      => "inbound",
  action         => "allow",
  protocol       => "tcp",
  profile        => ["private", "domain"],
  local_port     => 666,
  remote_port    => 6661,
  local_address  => "192.168.1.1",
  remote_address => "192.168.1.2",
  interface_type => ["wireless", "wired"],
}


windows_firewall_rule { "puppet - multiple ports":
  direction      => "inbound",
  action         => "allow",
  protocol       => "tcp",
  local_port     => "443,80,4243,5000-5010",
  remote_address => "any",
  remote_port    => "444,81,4244,6000-6010"
}

