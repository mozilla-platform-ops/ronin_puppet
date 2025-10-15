# Installs or verifies Homebrew using the Kandji silent installer script.
# This profile is idempotent and safe to re-run.
#
# It will:
#   • Deploy install_homebrew.sh to /usr/local/bin
#   • Execute the script if /opt/homebrew/bin/brew does not exist
#   • Leave a log at /Library/Logs/homebrew_install.log

class roles_profiles::profiles::homebrew_install {
  $installer_path = '/usr/local/bin/install_homebrew.sh'
  $brew_path      = '/opt/homebrew/bin/brew'

  # Ensure we have somewhere to store logs
  file { '/Library/Logs':
    ensure => directory,
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  # Copy the script into place
  file { $installer_path:
    ensure => file,
    source => 'puppet:///modules/roles_profiles/profiles/homebrew/install_homebrew.sh',
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  # Run installer if brew is missing
  exec { 'install_homebrew':
    command   => $installer_path,
    creates   => $brew_path,
    path      => ['/bin','/usr/bin','/usr/local/bin'],
    timeout   => 1800,  # 30-minute safety window
    logoutput => true,
  }

  notice("Homebrew verified or installed using Kandji script at ${installer_path}")
}
