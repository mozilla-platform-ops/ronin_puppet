# macos_reenable_spotlight/manifests/init.pp
#
# Reverses the effects of macos_disable_spotlight.
# Re-enables Spotlight indexing and the mds daemon so that
# com.apple.metadata:kMDItemWhereFroms xattrs are written correctly.
#
class macos_reenable_spotlight {
  # Remove the metadata_never_index sentinel file
  file { '/opt/worker/tasks/.metadata_never_index':
    ensure => absent,
  }

  # Remove the kill_background_processes.sh script
  file { '/usr/local/bin/kill_background_processes.sh':
    ensure => absent,
  }

  # Reload mds and re-enable Spotlight indexing globally
  exec { 'reenable_spotlight':
    command   => '/bin/bash -c "/bin/launchctl load -w /System/Library/LaunchDaemons/com.apple.metadata.mds.plist 2>/dev/null || true; \
     /usr/bin/mdutil -a -i on"',
    path      => ['/bin', '/usr/bin', '/usr/sbin', '/sbin'],
    unless    => '/usr/bin/mdutil -s / | grep -q "Indexing enabled"',
    logoutput => true,
  }

  # Re-enable indexing specifically for /opt/worker/tasks
  exec { 'reenable_spotlight_worker_tasks':
    command   => '/usr/bin/mdutil -i on /opt/worker/tasks 2>/dev/null || true',
    path      => ['/bin', '/usr/bin', '/usr/sbin', '/sbin'],
    unless    => '! test -d /opt/worker/tasks || mdutil -s /opt/worker/tasks 2>/dev/null | grep -q "Indexing enabled"',
    logoutput => true,
    require   => [
      File['/opt/worker/tasks/.metadata_never_index'],
      Exec['reenable_spotlight'],
    ],
  }
}
