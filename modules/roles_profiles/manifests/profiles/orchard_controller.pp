# Minimal Orchard controller profile (no Hiera lookups).
# Installs and manages the Orchard controller service on macOS.

class roles_profiles::profiles::orchard_controller {

  # Hardcoded values for initial bring-up — replace later with Hiera
  $controller_url = 'https://macmini-m4-194.test.releng.mdc1.mozilla.com'
  $version        = '0.6.3'

  # Create directories
  file { ['/opt/orchard','/opt/orchard/data','/opt/orchard/logs']:
    ensure => directory,
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  # Install Orchard controller binary (placeholder command)
  exec { 'install_orchard_controller':
    command => "/usr/local/bin/orchard-controller-install ${version}",
    creates => "/opt/orchard/bin/orchard-controller-${version}",
    path    => ['/usr/local/bin','/usr/bin','/bin'],
  }

  # Install LaunchDaemon for the Orchard service
  file { '/Library/LaunchDaemons/com.moz.orchard.controller.plist':
    ensure => file,
    source => 'puppet:///modules/roles_profiles/profiles/orchard_controller/controller.plist',
    owner  => 'root',
    group  => 'wheel',
    mode   => '0644',
  }

  # Start and enable the Orchard service
  service { 'com.moz.orchard.controller':
    ensure   => running,
    provider => launchd,
    enable   => true,
  }

  notice("Orchard controller service started at ${controller_url} (version ${version})")
}
