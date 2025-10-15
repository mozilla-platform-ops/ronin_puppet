# Orchard controller profile.
# Installs Orchard via Homebrew and manages the controller service on macOS.
#
# Assumes:
#   • Homebrew already installed in /opt/homebrew (by roles_profiles::profiles::homebrew_install)
#   • Default admin account is "admin"
#   • LaunchDaemon plist located at:
#       modules/roles_profiles/files/profiles/orchard_controller/controller.plist
#
# This class:
#   1. Fixes ownership of /opt/homebrew for the admin user
#   2. Installs Orchard via Homebrew (as admin)
#   3. Creates /opt/orchard data and log directories
#   4. Deploys and enables the LaunchDaemon for the Orchard controller

class roles_profiles::profiles::orchard_controller {
  # --------------------------------------------------------------------------
  # Hardcoded values for bring-up (migrate to Hiera later)
  # --------------------------------------------------------------------------
  $controller_url = 'https://macmini-m4-194.test.releng.mdc1.mozilla.com'

  # --------------------------------------------------------------------------
  # Ensure Homebrew permissions are correct
  # --------------------------------------------------------------------------
  exec { 'fix_homebrew_permissions':
    command => '/usr/sbin/chown -R admin:admin /opt/homebrew',
    unless  => '/usr/bin/stat -f "%Su" /opt/homebrew | /usr/bin/grep -q admin',
    path    => ['/bin','/usr/bin','/usr/sbin'],
  }

  # --------------------------------------------------------------------------
  # Install Orchard via Homebrew under the admin user context
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
    require     => Exec['fix_homebrew_permissions'],
  }

  # --------------------------------------------------------------------------
  # Directories for Orchard controller data/logs
  # --------------------------------------------------------------------------
  file { ['/opt/orchard','/opt/orchard/data','/opt/orchard/logs']:
    ensure => directory,
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  # --------------------------------------------------------------------------
  # Deploy LaunchDaemon plist for Orchard controller
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
  # Enable and start the LaunchDaemon
  # --------------------------------------------------------------------------
  service { 'com.moz.orchard.controller':
    ensure   => running,
    provider => launchd,
    enable   => true,
    require  => File['/Library/LaunchDaemons/com.moz.orchard.controller.plist'],
  }

  notice("Orchard controller installed via Homebrew and running at ${controller_url}")
}
