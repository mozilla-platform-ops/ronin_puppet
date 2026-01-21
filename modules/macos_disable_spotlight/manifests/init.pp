# macos_disable_spotlight/manifests/init.pp
#
# Disables Spotlight, media analysis daemons, and other background processes
# to reduce performance noise on macOS CI workers.
#
# Claude did this
class macos_disable_spotlight (
  Boolean $enabled = true
) {
  # Original Spotlight and media analysis disabling
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
    require => File['/opt/worker/tasks'],
  }

  # Explicitly disable indexing for /opt/worker/tasks
  exec { 'disable_spotlight_worker_tasks':
    command => '/bin/bash -c "/usr/bin/mdutil -i off /opt/worker/tasks 2>/dev/null || true; /bin/rm -rf /opt/worker/tasks/.Spotlight-V100 2>/dev/null || true"',
    creates => '/opt/worker/tasks/.metadata_never_index',
    require => File['/opt/worker/tasks/.metadata_never_index'],
  }

  # Disable additional background processes
  exec { 'disable_additional_background_processes':
    command     => '/bin/bash -c "
      # WebKit processes (GPU, WebContent, Networking)
      /usr/bin/pkill -9 com.apple.WebKit.GPU 2>/dev/null || true
      /usr/bin/pkill -9 com.apple.WebKit.WebContent 2>/dev/null || true
      /usr/bin/pkill -9 com.apple.WebKit.Networking 2>/dev/null || true

      # Music and media
      /usr/bin/pkill -9 MusicCacheExtension 2>/dev/null || true

      # Metal compiler
      /usr/bin/pkill -9 MTLCompilerService 2>/dev/null || true

      # Biome sync daemon
      /usr/bin/pkill -9 biomesyncd 2>/dev/null || true
      /bin/launchctl unload -w /System/Library/LaunchDaemons/com.apple.biomesyncd.plist 2>/dev/null || true

      # Parsec FBF
      /usr/bin/pkill -9 parsec-fbf 2>/dev/null || true

      # Keychain sandbox check
      /usr/bin/pkill -9 XPCKeychainSandboxCheck 2>/dev/null || true

      # iMessage services
      /usr/bin/pkill -9 IMDMessageServicesAgent 2>/dev/null || true
      /bin/launchctl unload -w /System/Library/LaunchAgents/com.apple.imagent.plist 2>/dev/null || true

      # Address Book sync
      /usr/bin/pkill -9 AddressBookSourceSync 2>/dev/null || true
      /usr/bin/pkill -9 AddressBookManager 2>/dev/null || true
      /bin/launchctl unload -w /System/Library/LaunchAgents/com.apple.AddressBook.ContactsAccountsService.plist 2>/dev/null || true
      /bin/launchctl unload -w /System/Library/LaunchAgents/com.apple.AddressBook.SourceSync.plist 2>/dev/null || true
    "',
    path        => ['/bin', '/usr/bin', '/usr/sbin', '/sbin'],
    logoutput   => true,
    refreshonly => false,
  }

  # Create a periodic check/kill script for processes that may restart
  file { '/usr/local/bin/kill_background_processes.sh':
    ensure  => file,
    owner   => 'root',
    group   => 'wheel',
    mode    => '0755',
    content => @("SCRIPT"/L),
      #!/bin/bash
      # Kill background processes that may restart during CI runs

      /usr/bin/pkill -9 com.apple.WebKit.GPU 2>/dev/null || true
      /usr/bin/pkill -9 com.apple.WebKit.WebContent 2>/dev/null || true
      /usr/bin/pkill -9 com.apple.WebKit.Networking 2>/dev/null || true
      /usr/bin/pkill -9 MusicCacheExtension 2>/dev/null || true
      /usr/bin/pkill -9 MTLCompilerService 2>/dev/null || true
      /usr/bin/pkill -9 biomesyncd 2>/dev/null || true
      /usr/bin/pkill -9 parsec-fbf 2>/dev/null || true
      /usr/bin/pkill -9 XPCKeychainSandboxCheck 2>/dev/null || true
      /usr/bin/pkill -9 IMDMessageServicesAgent 2>/dev/null || true
      /usr/bin/pkill -9 AddressBookSourceSync 2>/dev/null || true
      /usr/bin/pkill -9 AddressBookManager 2>/dev/null || true

      exit 0
      | SCRIPT
  }
}
