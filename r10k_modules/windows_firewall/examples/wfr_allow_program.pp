#@PDQTestWin
windows_firewall_rule { "puppet - allow messenger":
  ensure    => present,
  direction => "inbound",
  action    => "allow",
  program   => "C:\\programfiles\\messenger\\msnmsgr.exe",
}