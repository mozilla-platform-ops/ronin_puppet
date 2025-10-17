# Installs Tart from Cirrus Labs' official Homebrew tap,
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
  # Install Tart from the Cirrus Labs tap
  # ---------------------------------------------------------------------------
  exec { 'install_tart_via_tap':
    command     => '/usr/bin/su - admin -c "/opt/homebrew/bin/brew install cirruslabs/cli/tart || true"',
    unless      => '/opt/homebrew/bin/tart --version >/dev/null 2>&1',
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
  # Drop LaunchDaemon plist for Tart worker
  # ---------------------------------------------------------------------------
  file { '/Library/LaunchDaemons/com.mozilla.tartworker.plist':
    ensure  => file,
    source  => 'puppet:///modules/roles_profiles/profiles/tartworker/com.mozilla.tartworker.plist',
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    require => Exec['install_tart_via_tap'],
  }
}
