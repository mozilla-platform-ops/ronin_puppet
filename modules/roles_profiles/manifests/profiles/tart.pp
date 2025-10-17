# Installs Tart, configures registry access, and sets up a LaunchDaemon
# so each macOS worker runs Tart automatically.

class roles_profiles::profiles::tart (
  String  $version        = lookup('tart.version', { default_value => 'latest' }),
  String  $registry_host  = lookup('tart.registry_host', { default_value => 'registry.local' }),
  Integer $registry_port  = lookup('tart.registry_port', { default_value => 5000 }),
  Boolean $insecure       = lookup('tart.insecure', { default_value => true }),
) {

  # ---------------------------------------------------------------------------
  # Define a sane execution path and set defaults for all Exec/Package resources
  # ---------------------------------------------------------------------------
  Exec {
    path => [
      '/opt/homebrew/bin',   # Apple Silicon default
      '/usr/local/bin',      # Intel macOS default
      '/usr/bin',
      '/bin',
      '/usr/sbin',
      '/sbin'
    ],
  }

  Package {
    provider => brew,
  }

  # ---------------------------------------------------------------------------
  # Ensure Homebrew is installed before using it
  # ---------------------------------------------------------------------------
  require roles_profiles::profiles::homebrew_silent_install

  # ---------------------------------------------------------------------------
  # Install Tart via Homebrew
  # ---------------------------------------------------------------------------
  package { 'tart':
    ensure   => $version,
    provider => brew,
    path     => [
      '/opt/homebrew/bin',
      '/usr/local/bin',
      '/usr/bin',
      '/bin',
      '/usr/sbin',
      '/sbin'
    ],
    require  => Exec['install_homebrew'],
  }

  # ---------------------------------------------------------------------------
  # Configure registry connection file
  # ---------------------------------------------------------------------------
  file { '/etc/tart_registry.conf':
    ensure  => file,
    content => "registry=${registry_host}:${registry_port}\ninsecure=${insecure}\n",
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    require => Package['tart'],
  }

  # ---------------------------------------------------------------------------
  # Drop LaunchDaemon plist for Tart worker
  # ---------------------------------------------------------------------------
  file { '/Library/LaunchDaemons/com.mozilla.tartworker.plist':
    ensure  => file,
    source  => 'puppet:///modules/roles_profiles/profiles/tartworker/com.mozilla.tartworker.plist',
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    require => Package['tart'],
  }
}
