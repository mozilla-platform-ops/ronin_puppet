class macos_lsdb (
  Boolean $enabled = true,
) {
  if $enabled {
    file { '/usr/local/bin/lsdb.py':
      ensure => file,
      source => 'puppet:///modules/macos_lsdb/lsdb.py',
      mode   => '0755',
      owner  => 'root',
      group  => 'wheel',
    }
  }
}
