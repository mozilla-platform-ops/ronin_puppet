# macos_disable_spotlight/manifests/init.pp
#
# Disables Spotlight and media analysis daemons to reduce performance noise
# on macOS CI workers. Lightweight, runs once per Puppet apply.
#
class macos_disable_spotlight (
  Boolean $enabled = true,
) {
  if $enabled {
    exec { 'disable_spotlight_and_mediaanalysisd':
      command   => '/bin/bash -c "/usr/bin/mdutil -a -i off; \
       /bin/launchctl unload -w /System/Library/LaunchDaemons/com.apple.metadata.mds.plist 2>/dev/null || true; \
       /usr/bin/pkill -9 mdworker_shared 2>/dev/null || true; \
       /usr/bin/pkill -9 mediaanalysisd 2>/dev/null || true; \
       /bin/launchctl unload -w /System/Library/LaunchAgents/com.apple.mediaanalysisd.plist 2>/dev/null || true"',
      path      => ['/bin', '/usr/bin', '/usr/sbin', '/sbin'],
      unless    => '/usr/bin/mdutil -s / | grep -q "Indexing disabled"',
      logoutput => true,
    }

    # Create .metadata_never_index to prevent Spotlight from indexing this directory
    file { '/opt/worker/tasks/.metadata_never_index':
      ensure  => file,
      owner   => 'root',
      group   => 'wheel',
      mode    => '0644',
      require => Class['worker_runner'],  # this creates the /opt/worker/tasks dir
    }

    # Explicitly disable indexing for /opt/worker/tasks
    exec { 'disable_spotlight_worker_tasks':
      command => '/bin/bash -c "/usr/bin/mdutil -i off /opt/worker/tasks 2>/dev/null || true; /bin/rm -rf /opt/worker/tasks/.Spotlight-V100 2>/dev/null || true"',
      onlyif  => '/usr/bin/test -d /opt/worker/tasks',
      require => File['/opt/worker/tasks/.metadata_never_index'],
    }
  }
}
