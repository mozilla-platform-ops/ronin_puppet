# Installs or verifies Homebrew using the Kandji silent installer script.
# Apple Silicon–native version that installs into /opt/homebrew.

class roles_profiles::profiles::homebrew_install {
  $installer_path = '/opt/homebrew/bin/install_homebrew.sh'
  $brew_path      = '/opt/homebrew/bin/brew'

  # --------------------------------------------------------------------------
  # Create /opt/homebrew parent (SIP allows /opt but not deeper dirs)
  # --------------------------------------------------------------------------
  file { '/opt/homebrew':
    ensure => directory,
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  file { '/opt/homebrew/bin':
    ensure  => directory,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0755',
    require => File['/opt/homebrew'],
  }

  file { '/Library/Logs':
    ensure => directory,
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  # --------------------------------------------------------------------------
  # Deploy Kandji installer script
  # --------------------------------------------------------------------------
  file { $installer_path:
    ensure  => file,
    source  => 'puppet:///modules/roles_profiles/profiles/homebrew/install_homebrew.sh',
    owner   => 'root',
    group   => 'wheel',
    mode    => '0755',
    require => File['/opt/homebrew/bin'],
  }

  # --------------------------------------------------------------------------
  # Execute installer only if brew is missing
  # --------------------------------------------------------------------------
  exec { 'install_homebrew':
    command   => $installer_path,
    creates   => $brew_path,
    path      => ['/bin','/usr/bin','/opt/homebrew/bin'],
    timeout   => 1800,
    logoutput => true,
    require   => File[$installer_path],
  }

  notice("Homebrew verified or installed using Kandji script at ${installer_path}")
}
