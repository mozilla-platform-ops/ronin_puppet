# Installs or verifies Homebrew using the Kandji silent installer script.
# Apple Silicon–native version that installs into /opt/homebrew.
#
# Actions:
#   • Ensure /opt/homebrew/bin exists
#   • Deploy install_homebrew.sh to /opt/homebrew/bin
#   • Execute the installer if /opt/homebrew/bin/brew does not exist
#   • Log output to /Library/Logs/homebrew_install.log
#
# Idempotent — safe to rerun.
# Requires: modules/roles_profiles/files/profiles/homebrew/install_homebrew.sh

class roles_profiles::profiles::homebrew_install {
  # --------------------------------------------------------------------------
  # Variables
  # --------------------------------------------------------------------------
  $installer_path = '/opt/homebrew/bin/install_homebrew.sh'
  $brew_path      = '/opt/homebrew/bin/brew'

  # --------------------------------------------------------------------------
  # Ensure directories exist
  # --------------------------------------------------------------------------
  file { '/opt/homebrew/bin':
    ensure => directory,
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
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
    ensure => file,
    source => 'puppet:///modules/roles_profiles/profiles/homebrew/install_homebrew.sh',
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  # --------------------------------------------------------------------------
  # Execute installer only if brew is missing
  # --------------------------------------------------------------------------
  exec { 'install_homebrew':
    command   => $installer_path,
    creates   => $brew_path,
    path      => ['/bin','/usr/bin','/opt/homebrew/bin'],
    timeout   => 1800,   # up to 30 minutes
    logoutput => true,
    require   => File[$installer_path],
  }

  # --------------------------------------------------------------------------
  # Log notice for visibility
  # --------------------------------------------------------------------------
  notice("Homebrew verified or installed using Kandji script at ${installer_path}")
}
