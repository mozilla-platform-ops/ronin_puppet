# @PDQTestWin

windows_firewall_profile { 'domain':
  inboundusernotification    => 'enable',
  firewallpolicy             => 'allowinbound,allowoutbound',
  logallowedconnections      => 'enable',
  logdroppedconnections      => 'enable',
  maxfilesize                => '4000',
  remotemanagement           => 'enable',
  state                      => 'on',
  unicastresponsetomulticast => 'enable',
}