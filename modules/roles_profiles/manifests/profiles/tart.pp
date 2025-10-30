# Installs Tart from Cirrus Labs' official Homebrew tap,
# configures registry access, and sets up LaunchDaemons
# so two macOS Tart VMs run automatically after Puppet apply.

class roles_profiles::profiles::tart (
  String  $version        = lookup('tart.version', { default_value => 'latest' }),
  String  $registry_host  = lookup('tart.registry_host', { default_value => 'registry.local' }),
  Integer $registry_port  = lookup('tart.registry_port', { default_value => 5000 }),
  Boolean $insecure       = lookup('tart.insecure', { default_value => true }),
) {

  # ---------------------------------------------------------------------------
  # Default PATH for all Exec resources
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
  # Ensure Homebrew is installed and writable
  # ---------------------------------------------------------------------------
  require roles_profiles::profiles::homebrew_silent_install

  File <| title == '/opt/homebrew/bin' |> {
    owner => 'admin',
    group => 'admin',
    mode  => '0755',
  }

  # ---------------------------------------------------------------------------
  # Add Cirrus Labs Homebrew tap if not present
  # ---------------------------------------------------------------------------
  exec { 'brew_tap_cirruslabs_cli':
    command     => '/usr/bin/su - admin -c "/opt/homebrew/bin/brew tap cirruslabs/cli"',
    unless      => '/usr/bin/su - admin -c "/opt/homebrew/bin/brew tap | grep -q cirruslabs/cli"',
    environment => ['HOME=/Users/admin'],
    logoutput   => true,
  }

  # ---------------------------------------------------------------------------
  # Install Tart from Cirrus Labs tap
  # ---------------------------------------------------------------------------
  exec { 'install_tart_via_tap':
    command     => '/usr/bin/su - admin -c "/opt/homebrew/bin/brew install cirruslabs/cli/tart || true"',
    unless      => 'test -x /opt/homebrew/bin/tart',
    environment => ['HOME=/Users/admin'],
    require     => Exec['brew_tap_cirruslabs_cli'],
    logoutput   => true,
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
    require => Exec['install_tart_via_tap'],
  }

  # ---------------------------------------------------------------------------
  # First LaunchDaemon: com.mozilla.tartworker (VM #1)
  # ---------------------------------------------------------------------------
  file { '/Library/LaunchDaemons/com.mozilla.tartworker.plist':
    ensure  => file,
    source  => 'puppet:///modules/roles_profiles/profiles/tartworker/com.mozilla.tartworker.plist',
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    require => Exec['install_tart_via_tap'],
  }

  # ---------------------------------------------------------------------------
  # Second LaunchDaemon: com.mozilla.tartworker2 (VM #2)
  # ---------------------------------------------------------------------------
  file { '/Library/LaunchDaemons/com.mozilla.tartworker2.plist':
    ensure  => file,
    source  => 'puppet:///modules/roles_profiles/profiles/tartworker/com.mozilla.tartworker2.plist',
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    require => Exec['install_tart_via_tap'],
  }

  # ---------------------------------------------------------------------------
  # Load both LaunchDaemons immediately (no reboot needed)
  # ---------------------------------------------------------------------------
  exec { 'load_tart_daemon_1':
    command   => '/bin/launchctl bootstrap system /Library/LaunchDaemons/com.mozilla.tartworker.plist',
    unless    => '/bin/launchctl list | grep -q com.mozilla.tartworker',
    path      => ['/bin', '/usr/bin', '/usr/sbin', '/sbin'],
    require   => File['/Library/LaunchDaemons/com.mozilla.tartworker.plist'],
    logoutput => true,
  }

  exec { 'load_tart_daemon_2':
    command   => '/bin/launchctl bootstrap system /Library/LaunchDaemons/com.mozilla.tartworker2.plist',
    unless    => '/bin/launchctl list | grep -q com.mozilla.tartworker2',
    path      => ['/bin', '/usr/bin', '/usr/sbin', '/sbin'],
    require   => File['/Library/LaunchDaemons/com.mozilla.tartworker2.plist'],
    logoutput => true,
  }
}
