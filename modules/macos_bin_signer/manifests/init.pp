class macos_bin_signer (
  Boolean $enabled = true,
) {
  # Ensure the start-worker script is present and executable
  file { '/usr/local/bin/start-worker':
    ensure => file,
    mode   => '0755',
    owner  => 'root',
    group  => 'wheel',
    source => 'puppet:///modules/macos_bin_signer/start-worker',
  }

  # Ensure the start-worker script is signed
  exec { 'codesign_start_worker':
    command => 'codesign --force --sign - /usr/local/bin/start-worker',
    path    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
    require => File['/usr/local/bin/start-worker'], # Ensure file exists first
    unless  => 'codesign --verify /usr/local/bin/start-worker',
  }
}
