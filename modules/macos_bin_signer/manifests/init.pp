class macos_bin_signer (
  Boolean $enabled = true,
) {
  # Addresses: https://bugzilla.mozilla.org/show_bug.cgi?id=1932140
  # Ensure the start-worker binary is signed
  exec { 'codesign_start_worker':
    command => 'codesign --force --sign - /usr/local/bin/start-worker',
    path    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
    require => File['/usr/local/bin/start-worker'], # Ensure file exists first
    unless  => 'codesign --verify /usr/local/bin/start-worker',
  }
}
