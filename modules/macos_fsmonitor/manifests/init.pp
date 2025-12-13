class macos_fsmonitor (
  Boolean $enabled = true,
) {
  # Install the watchman package from S3
  packages::macos_package_from_s3 { 'watchman.pkg':
    private             => false,
    os_version_specific => false,
    type                => 'pkg',
    require             => Exec['prepare_watchman_dir'],
  }

  # these directories only exist after restart, so in ci, let's skip this
  if $facts['running_in_test_kitchen'] != 'true' {
    # Step 1: Create the necessary directory
    exec { 'prepare_watchman_dir':
      command => 'sudo mkdir -p /usr/local/var/run/watchman',
      creates => '/usr/local/var/run/watchman',
      path    => ['/usr/bin', '/usr/local/bin'],
    }

    # Step 2: Adjust ownership of the directory
    exec { 'chown_watchman_dir':
      command => 'sudo chown -R cltbld:staff /usr/local/var/run/watchman',
      require => Exec['prepare_watchman_dir'],
      path    => ['/usr/bin', '/usr/local/bin'],
    }
  }

  # Step 3: Codesign the `watchman` binary
  exec { 'codesign_watchman':
    command => 'sudo codesign --force --sign - /usr/local/bin/watchman',
    onlyif  => '/bin/test -f /usr/local/bin/watchman',
    require => Packages::Macos_package_from_s3['watchman.pkg'],
    path    => ['/usr/bin', '/usr/local/bin', '/bin'],
  }

  # Step 4: Codesign the `watchmanctl` binary
  exec { 'codesign_watchmanctl':
    command => 'sudo codesign --force --sign - /usr/local/bin/watchmanctl',
    onlyif  => '/bin/test -f /usr/local/bin/watchmanctl',
    require => Packages::Macos_package_from_s3['watchman.pkg'],
    path    => ['/usr/bin', '/usr/local/bin', '/bin'],
  }

  # Step 5: Install the pywatchman package using pip
  exec { 'install_pywatchman':
    command => '/usr/local/bin/pip3.11 install pywatchman==2.0.0',
    unless  => '/usr/local/bin/python3 -c "import pywatchman"',
    path    => ['/usr/local/bin', '/usr/bin'],
  }

  # Step 6: Append fsmonitor config to existing .hgrc if enabled
  if $enabled {
    file_line { 'add_fsmonitor_extension':
      path    => '/Users/cltbld/.hgrc',
      line    => 'fsmonitor =',
      match   => '^fsmonitor\s*=',
      after   => '^sparse\s*=',
      require => File['/Users/cltbld/.hgrc'],
    }

    file_line { 'add_fsmonitor_section':
      path    => '/Users/cltbld/.hgrc',
      line    => '[fsmonitor]',
      match   => '^\[fsmonitor\]',
      require => File_line['add_fsmonitor_extension'],
    }

    file_line { 'add_fsmonitor_mode':
      path    => '/Users/cltbld/.hgrc',
      line    => 'mode = paranoid',
      match   => '^mode\s*=',
      require => File_line['add_fsmonitor_section'],
    }
  }
}
