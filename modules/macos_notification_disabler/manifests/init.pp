class macos_notification_disabler {

  # This class enables the "Do Not Disturb" (Focus Mode) feature in macOS
  # by setting up the required directories and copying necessary configuration files.
  # Note: A logout and log back in are required for changes to take effect.

  # Ensure the base directory exists for Do Not Disturb settings
  file { '/Users/cltbld/Library/DoNotDisturb':
    ensure => 'directory',
    owner  => 'cltbld',
    group  => 'staff',
    mode   => '0755',
  }

  # Ensure the DB directory exists for storing configuration files
  file { '/Users/cltbld/Library/DoNotDisturb/DB':
    ensure  => 'directory',
    owner   => 'cltbld',
    group   => 'staff',
    mode    => '0755',
    require => File['/Users/cltbld/Library/DoNotDisturb'],
  }

  # Define the configuration files needed to enable Do Not Disturb mode
  $files = [
    'Assertions.json',
    'Metrics.json',
    'Settings.sqlite',
    'Settings.sqlite-shm'
  ]

  # Copy the configuration files from the Puppet module to the DB directory
  # These files contain the necessary settings for Do Not Disturb mode.
  file { $files:
    ensure  => 'file',
    source  => "puppet:///modules/${module_name}/DoNotDisturb/${name}",
    path    => "/Users/cltbld/Library/DoNotDisturb/DB/${name}",
    owner   => 'cltbld',
    group   => 'staff',
    mode    => '0644',
    require => File['/Users/cltbld/Library/DoNotDisturb/DB'],
  }
}
