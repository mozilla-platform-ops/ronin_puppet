# Ensures Homebrew and Xcode Command-Line Tools are installed silently
# using the trusted Kandji installer script.
#
# Logs to /Library/Logs/homebrew_install.log and only runs once.

class roles_profiles::profiles::homebrew_silent_install {

  # Ensure /opt and /opt/homebrew paths exist
  file { ['/opt', '/opt/homebrew', '/opt/homebrew/bin']:
    ensure => directory,
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  # Deploy Kandji Homebrew installer script
  file { '/opt/homebrew/bin/install_homebrew.sh':
    ensure  => file,
    source  => 'puppet:///modules/roles_profiles/profiles/homebrew/install_homebrew.sh',
    owner   => 'root',
    group   => 'wheel',
    mode    => '0755',
    require => File['/opt/homebrew/bin'],
  }

  # Run the installer only if Homebrew is missing
  exec { 'install_homebrew':
    command   => '/opt/homebrew/bin/install_homebrew.sh',
    unless    => 'test -x /opt/homebrew/bin/brew',
    path      => ['/usr/bin','/bin','/usr/sbin','/sbin'],
    require   => File['/opt/homebrew/bin/install_homebrew.sh'],
    logoutput => true,
  }
}
