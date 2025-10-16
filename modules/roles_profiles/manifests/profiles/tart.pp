class roles_profiles::profiles::tart (
  String $version        = lookup('tart.version', { default_value => 'latest' }),
  String $registry_host  = lookup('tart.registry_host', { default_value => 'registry.local' }),
  Integer $registry_port = lookup('tart.registry_port', { default_value => 5000 }),
  Boolean $insecure      = lookup('tart.insecure', { default_value => true }),
) {
  package { 'tart':
    ensure   => $version,
    provider => brew,
  }

  file { '/etc/tart_registry.conf':
    ensure  => file,
    content => "registry=${registry_host}:${registry_port}\ninsecure=${insecure}\n",
    mode    => '0644',
  }

  file { '/Library/LaunchDaemons/com.mozilla.tartworker.plist':
    ensure => file,
    source => 'puppet:///modules/roles_profiles/profiles/tartworker/com.mozilla.tartworker.plist',
    owner  => 'root',
    group  => 'wheel',
    mode   => '0644',
  }
}
