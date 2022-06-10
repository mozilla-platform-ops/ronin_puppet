# @PDQTestWin
windows_firewall_profile { ['public', 'private']:
  state => 'off',
}

windows_firewall_profile { 'domain':
  state => false,
}