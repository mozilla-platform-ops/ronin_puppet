# Orchard controller profile.
# Installs Orchard via Homebrew (cirruslabs/cli tap) and manages the controller service on macOS.

class roles_profiles::profiles::orchard_controller {
  # --------------------------------------------------------------------------
  # Hardcoded values for bring-up (migrate to Hiera later)
  # --------------------------------------------------------------------------
  $controller_url = 'https://macmini-m4-194.test.releng.mdc1.mozilla.com'

  # --------------------------------------------------------------------------
  # Ensure correct Homebrew ownership
  # --------------------------------------------------------------------------
  exec { 'fix_homebrew_permissions':
    command => '/usr/sbin/chown -R admin:admin /opt/homebrew',
    unless  => '/usr/bin/stat -f "%Su" /opt/homebrew | /usr/bin/grep -q admin',
    path    => ['/bin','/usr/bin','/usr/sbin'],
  }

  # --------------------------------------------------------------------------
  # Add CirrusLabs tap (required for orchard and tart)
  # --------------------------------------------------------------------------
  exec { 'tap_cirruslabs_cli':
    command     => '/usr/bin/su - admin -c "/opt/homebrew/bin/brew tap cirruslabs/cli"',
    unless      => '/usr/bin/su - admin -c "/opt/homebrew/bin/brew tap | /usr/bin/grep -q cirruslabs/cli"',
    path        => ['/bin','/usr/bin','/opt/homebrew/bin'],
    environment => [
      'HOME=/Users/admin',
      'USER=admin',
      'LOGNAME=admin',
    ],
    timeout     => 120,
    logoutput   => true,
    require     => Exec['fix_homebrew_permissions'],
  }

  # --------------------------------------------------------------------------
  # Install Orchard via Homebrew under admin user context
  # --------------------------------------------------------------------------
  exec { 'install_orchard_via_brew':
    command     => '/usr/bin/su - admin -c "/opt/homebrew/bin/brew install orchard"',
    unless      => '/usr/bin/su - admin -c "/opt/homebrew/bin/brew list orchard >/dev/null 2>&1"',
    path        => ['/bin','/usr/bin','/opt/homebrew/bin'],
    environment => [
      'HOME=/Users/admin',
      'USER=admin',
      'LOGNAME=admin',
    ],
    timeout     => 900,
    logoutput   => true,
    require     => Exec['tap_cirruslabs_cli'],
  }

  # --------------------------------------------------------------------------
  # Directories for Orchard data/logs
  # --------------------------------------------------------------------------
  file { ['/opt/orchard','/opt/orchard/data','/opt/orchard/logs']:
    ensure => directory,
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  # --------------------------------------------------------------------------
  # LaunchDaemon for Orchard controller
  # --------------------------------------------------------------------------
  file { '/Library/LaunchDaemons/com.moz.orchard.controller.plist':
    ensure  => file,
    source  => 'puppet:///modules/roles_profiles/profiles/orchard_controller/controller.plist',
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    require => Exec['install_orchard_via_brew'],
  }

  # --------------------------------------------------------------------------
  # Start and enable the LaunchDaemon
  # --------------------------------------------------------------------------
  service { 'com.moz.orchard.controller':
    ensure   => running,
    provider => launchd,
    enable   => true,
    require  => File['/Library/LaunchDaemons/com.moz.orchard.controller.plist'],
  }

  notice("Orchard controller installed via Homebrew (cirruslabs/cli tap) and running at ${controller_url}")
}
