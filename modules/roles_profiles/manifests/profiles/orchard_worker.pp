# Orchard worker profile
# Installs Orchard via Homebrew and manages the worker service that connects to the controller.

class roles_profiles::profiles::orchard_worker {

  $controller_url = 'https://macmini-m4-194.test.releng.mdc1.mozilla.com:6120'

  # --------------------------------------------------------------------------
  # Ensure Homebrew ownership for admin (same as controller)
  # --------------------------------------------------------------------------
  exec { 'fix_homebrew_permissions':
    command => '/usr/sbin/chown -R admin:admin /opt/homebrew',
    unless  => '/usr/bin/stat -f "%Su" /opt/homebrew | /usr/bin/grep -q admin',
    path    => ['/bin','/usr/bin','/usr/sbin'],
  }

  # --------------------------------------------------------------------------
  # Add CirrusLabs tap and install Orchard via Homebrew
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
  # Create Orchard directories
  # --------------------------------------------------------------------------
  file { ['/opt/orchard','/opt/orchard/logs']:
    ensure => directory,
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  # --------------------------------------------------------------------------
  # Deploy the LaunchDaemon for the worker
  # --------------------------------------------------------------------------
  file { '/Library/LaunchDaemons/com.moz.orchard.worker.plist':
    ensure  => file,
    source  => 'puppet:///modules/roles_profiles/profiles/orchard_worker/worker.plist',
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    require => Exec['install_orchard_via_brew'],
  }

  # --------------------------------------------------------------------------
  # Start and enable the worker service
  # --------------------------------------------------------------------------
  service { 'com.moz.orchard.worker':
    ensure   => running,
    provider => launchd,
    enable   => true,
    require  => File['/Library/LaunchDaemons/com.moz.orchard.worker.plist'],
  }

  notice("Orchard worker installed and connecting to ${controller_url}")
}
