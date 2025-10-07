exec { 'disable_spotlight_and_mediaanalysisd':
  command => '/usr/local/bin/disable_indexing.sh',
  path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin', '/usr/local/bin'],
  creates => '/var/db/.indexing_disabled',
}
