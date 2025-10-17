# Installs Tart, configures registry access, and sets up a LaunchDaemon
# so each macOS worker runs Tart automatically.

class roles_profiles::profiles::tart (
  String  $version        = lookup('tart.version', { default_value => 'latest' }),
  String  $registry_host  = lookup('tart.registry_host', { default_value => 'registry.local' }),
  Integer $registry_port  = lookup('tart.registry_port', { default_value => 5000 }),
  Boolean $insecure       = lookup('tart.insecure', { default_value => true }),
) {

  # ---------------------------------------------------------------------------
  # Define a sane execution path for all execs
  # ---------------------------------------------------------------------------
  Exec {
    path => [
      '/opt/homebrew/bin',
      '/usr/local/bin',
      '/usr/bin',
      '/bin',
      '/usr/sbin',
      '/sbin',
    ],
  }

  # ---------------------------------------------------------------------------
  # Ensure Homebrew is installed before using it
  # ---------------------------------------------------------------------------
  require roles_profiles::profiles::homebrew_silent_install

  # ---------------------------------------------------------------------------
  # Install Tart directly via exec to avoid brew provider path issues
  # ---------------------------------------------------------------------------
  exec { 'install_tart_via_brew':
    command   => '/opt/homebrew/bin/brew install --quiet tart || true',
    unless    => '/opt/homebrew/bin/brew list tart >/dev/null 2>&1',
    require   => Exec['install_homebrew'],
    logoutput => true,
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
    require => Exec['install_tart_via_brew'],
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
    require => Exec['install_tart_via_brew'],
  }
}
