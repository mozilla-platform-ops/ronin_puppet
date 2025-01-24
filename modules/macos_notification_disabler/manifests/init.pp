# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_notification_disabler (
  Boolean $enabled = true,
) {
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
    'Settings.sqlite-shm',
  ]

  # Loop through the files array to create each file resource
  $files.each |String $file| {
    file { "/Users/cltbld/Library/DoNotDisturb/DB/${file}":
      ensure  => 'file',
      source  => "puppet:///modules/macos_notification_disabler/${file}",
      owner   => 'cltbld',
      group   => 'staff',
      mode    => '0644',
      require => File['/Users/cltbld/Library/DoNotDisturb/DB'],
    }
  }
}
