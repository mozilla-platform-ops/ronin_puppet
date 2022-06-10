# @PDQTestWin
windows_firewall_rule { "puppet - test numeric protocol IGMP":
  direction   => 'inbound',
  action      => 'allow',
  protocol    => '2',
  program     => 'System',
  description => 'Core Networking - Internet Group Management Protocol (IGMP-In)',
}