# macos_disable_spotlight/manifests/init.pp
#
# Disables Spotlight and media analysis daemons to reduce performance noise
# on macOS CI workers. Lightweight, runs once per Puppet apply.
#
class macos_disable_spotlight {
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
}
