# Installs Tart directly from Cirrus Labs GitHub releases,
# configures registry access, and sets up a LaunchDaemon
# so each macOS worker runs Tart automatically.

class roles_profiles::profiles::tart (
  String  $version        = lookup('tart.version', { default_value => 'latest' }),
  String  $registry_host  = lookup('tart.registry_host', { default_value => 'registry.local' }),
  Integer $registry_port  = lookup('tart.registry_port', { default_value => 5000 }),
  Boolean $insecure       = lookup('tart.insecure', { default_value => true }),
) {

  # ---------------------------------------------------------------------------
  # Default execution PATH for all exec resources
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
  # Ensure Homebrew prerequisites are in place (directory + permissions)
  # ---------------------------------------------------------------------------
  require roles_profiles::profiles::homebrew_silent_install

  # Adjust ownership of /opt/homebrew/bin declared in homebrew_silent_install
  File <| title == '/opt/homebrew/bin' |> {
    owner => 'admin',
    group => 'admin',
    mode  => '0755',
  }

  # ---------------------------------------------------------------------------
  # Download the Tart .pkg from Cirrus Labs GitHub releases
  # ---------------------------------------------------------------------------
  exec { 'download_tart_pkg':
    command   => '/usr/bin/curl -L -o /var/tmp/tart-latest.pkg https://github.com/cirruslabs/tart/releases/latest/download/tart.pkg',
    creates   => '/var/tmp/tart-latest.pkg',
    path      => ['/usr/bin','/bin'],
    logoutput => true,
  }

  # ---------------------------------------------------------------------------
  # Install Tart directly via the downloaded .pkg
  # ---------------------------------------------------------------------------
  exec { 'install_tart_direct':
    command   => '/usr/sbin/installer -verboseR -pkg /var/tmp/tart-latest.pkg -target /',
    creates   => '/opt/homebrew/bin/tart',
    path      => ['/usr/bin','/bin','/usr/sbin','/sbin'],
    unless    => 'test -x /opt/homebrew/bin/tart',
    require   => Exec['download_tart_pkg'],
    logoutput => true,
    before    => [ File['/etc/tart_registry.conf'], File['/Library/LaunchDaemons/com.mozilla.tartworker.plist'] ],
    notify    => Exec['cleanup_tart_pkg'],
  }

  # ---------------------------------------------------------------------------
  # Cleanup the .pkg after successful installation
  # ---------------------------------------------------------------------------
  exec { 'cleanup_tart_pkg':
    command     => '/bin/rm -f /var/tmp/tart-latest.pkg',
    refreshonly => true,
    path        => ['/usr/bin','/bin'],
  }

  # Explicit ordering
  Exec['download_tart_pkg'] -> Exec['install_tart_direct'] -> Exec['cleanup_tart_pkg']

  # ---------------------------------------------------------------------------
  # Configure registry connection file
  # ---------------------------------------------------------------------------
  file { '/etc/tart_registry.conf':
    ensure  => file,
    content => "registry=${registry_host}:${registry_port}\ninsecure=${insecure}\n",
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    require => Exec['install_tart_direct'],
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
    require => Exec['install_tart_direct'],
  }
}
