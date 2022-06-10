# @PDQTestWin
windows_firewall_global { 'global':
  authzcomputergrp  => 'none',
  authzusergrp      => 'none',
  defaultexemptions => ['neighbordiscovery','dhcp'],
  forcedh           => 'yes',
  ipsecthroughnat   => 'serverbehindnat',
  keylifetime       => '485min,0sess',
  saidletimemin     => '6',
  secmethods        => 'dhgroup2:aes128-sha1,dhgroup2:3des-sha1',
  statefulftp       => 'disable',
  statefulpptp      => 'disable',
  strongcrlcheck    => '1',
}