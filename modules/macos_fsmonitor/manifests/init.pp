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

  # Step 5: Manage `.hgrc` file for cltbld
  file { '/Users/cltbld/.hgrc':
    ensure  => file,
    owner   => 'cltbld',
    group   => 'staff',
    mode    => '0644',
    content => epp('macos_fsmonitor/hgrc.epp'), # Use a template for consistent content.
    require => Exec['codesign_watchman'],
  }

  # Embedded Puppet Template (hgrc.epp)
  # This template will look like this:
  #
  # <%# macos_fsmonitor/hgrc.epp %>
  # [diff]
  # git=True
  # showfunc=True
  # ignoreblanklines=True
  #
  # [ui]
  # username = Mozilla Release Engineering <release@mozilla.com>
  # traceback = True
  #
  # [extensions]
  # share=
  # rebase=
  # mq=
  # purge=
  # robustcheckout=/usr/local/lib/hgext/robustcheckout.py
  # sparse=
  # fsmonitor =
  #
  # [fsmonitor]
  # mode = paranoid
  #
  # [web]
  # cacerts = /etc/mercurial/cacert.pem
}
