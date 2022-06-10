# @PDQTestWin
windows_firewall_profile { ['public', 'private']:
  state => 'on',
}
windows_firewall_profile { 'domain':
  state => true,
}