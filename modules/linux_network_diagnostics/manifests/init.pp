# Retain a bounded history across reboot; disabling collection preserves evidence.
class linux_network_diagnostics (
  Boolean $enabled = false,
) {
  file { '/usr/local/sbin/network-snapshot':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/linux_network_diagnostics/network-snapshot',
  }
  file { '/var/log/network-snapshots':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
  }
  ['network-snapshot.service', 'network-snapshot.timer'].each |String $unit| {
    file { "/etc/systemd/system/${unit}":
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      source => "puppet:///modules/linux_network_diagnostics/${unit}",
    }
  }
  exec { 'network-snapshot-daemon-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
    subscribe   => File['/etc/systemd/system/network-snapshot.service', '/etc/systemd/system/network-snapshot.timer'],
  }
  $timer_state = $enabled ? { true => running, default => stopped }
  service { 'network-snapshot.timer':
    ensure  => $timer_state,
    enable  => $enabled,
    require => [Exec['network-snapshot-daemon-reload'], File['/usr/local/sbin/network-snapshot', '/var/log/network-snapshots']],
  }
  if !$enabled {
    service { 'network-snapshot.service':
      ensure  => stopped,
      enable  => false,
      require => Service['network-snapshot.timer'],
    }
  }
}
