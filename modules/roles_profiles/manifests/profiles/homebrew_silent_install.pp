# Ensures Homebrew and Xcode Command-Line Tools are installed silently
# using the trusted Kandji installer script.
#
# Logs to /Library/Logs/homebrew_install.log and only runs once.

class roles_profiles::profiles::homebrew_silent_install {

  file { '/opt/homebrew/bin':
    ensure => directory,
  }

  # Deploy Kandji Homebrew installer script
  file { '/opt/homebrew/bin/install_homebrew.sh':
    ensure => file,
    source => 'puppet:///modules/roles_profiles/profiles/homebrew/install_homebrew.sh',
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  # Execute the installer if Homebrew isn't already present
  exec { 'install_homebrew':
    command => '/opt/homebrew/bin/install_homebrew.sh',
    creates => '/opt/homebrew/bin/brew',
    path    => ['/usr/bin','/bin','/usr/sbin','/sbin'],
  }
}
