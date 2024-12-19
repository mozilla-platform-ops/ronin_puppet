class macos_fsmonitor (
  Boolean $enabled = true,
) {
  # Install the watchman package from S3
  packages::macos_package_from_s3 { 'watchman.pkg':
    private             => false,
    os_version_specific => false,
    type                => 'pkg',
    require             => Exec['prepare_watchman_dir'], # Ensure the directory is created before the package is used.
  }

  # Step 1: Create the necessary directory
  exec { 'prepare_watchman_dir':
    command => 'sudo mkdir -p /usr/local/var/run/watchman',
    creates => '/usr/local/var/run/watchman', # Ensures this is idempotent.
    path    => ['/usr/bin', '/usr/local/bin'], # Ensure `mkdir` is found in the PATH.
  }

  # Step 2: Adjust ownership of the directory
  exec { 'chown_watchman_dir':
    command => 'sudo chown -R cltbld:staff /usr/local/var/run/watchman',
    require => Exec['prepare_watchman_dir'], # Run only after the directory is created.
    path    => ['/usr/bin', '/usr/local/bin'],
  }

  # Step 3: Codesign the `watchman` binary
  exec { 'codesign_watchman':
    command => 'sudo codesign --force --sign - /usr/local/bin/watchman',
    onlyif  => '/bin/test -f /usr/local/bin/watchman', # Specify full path to 'test'.
    require => Packages::Macos_package_from_s3['watchman.pkg'],
    path    => ['/usr/bin', '/usr/local/bin', '/bin'],
  }

  # Step 4: Codesign the `watchmanctl` binary
  exec { 'codesign_watchmanctl':
    command => 'sudo codesign --force --sign - /usr/local/bin/watchmanctl',
    onlyif  => '/bin/test -f /usr/local/bin/watchmanctl', # Specify full path to 'test'.
    require => Packages::Macos_package_from_s3['watchman.pkg'],
    path    => ['/usr/bin', '/usr/local/bin', '/bin'],
  }

  # Step 5: Append configuration to `.hgrc` for cltbld
  file_line { 'enable_fsmonitor_plugin':
    path    => '/Users/cltbld/.hgrc',
    line    => '[extensions]\nfsmonitor =',
    match   => '^\[extensions\]',
    require => Exec['codesign_watchman'], # Ensure this runs after Watchman setup.
  }

  file_line { 'configure_fsmonitor_mode':
    path    => '/Users/cltbld/.hgrc',
    line    => '[fsmonitor]\nmode = paranoid',
    match   => '^\[fsmonitor\]',
    require => Exec['codesign_watchman'],
  }

  # Ensure correct ownership and permissions of .hgrc
  file { '/Users/cltbld/.hgrc':
    ensure => file,
    owner  => 'cltbld',
    group  => 'staff',
    mode   => '0644',
  }
}
