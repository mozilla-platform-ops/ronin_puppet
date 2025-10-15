# Orchard controller profile.
# Installs Orchard via Homebrew and manages the controller service on macOS.

class roles_profiles::profiles::orchard_controller {

  # Hardcoded values for initial bring-up — will move to Hiera later
  $controller_url = 'https://macmini-m4-194.test.releng.mdc1.mozilla.com'

  # --------------------------------------------------------------------------
  # Ensure Orchard is installed via Homebrew
  # --------------------------------------------------------------------------
  # Homebrew is assumed to have been installed already by the
  # roles_profiles::profiles::homebrew_install profile.

  exec { 'install_orchard_via_brew':
    command => '/opt/homebrew/bin/brew install orchard',
    unless  => '/opt/homebrew/bin/brew list orchard >/dev/null 2>&1',
    path    => ['/bin','/usr/bin','/opt/homebrew/bin'],
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
  # LaunchDaemon for the Orchard controller
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
  # Manage the Orchard service
  # --------------------------------------------------------------------------
  service { 'com.moz.orchard.controller':
    ensure   => running,
    provider => launchd,
    enable   => true,
    require  => File['/Library/LaunchDaemons/com.moz.orchard.controller.plist'],
  }

  notice("Orchard controller installed via Homebrew and running at ${controller_url}")
}
