class macos_sbom (
  Boolean $enabled = true,
) {
# Ensure the SBOM script is in place
  file { '/usr/local/bin/generate_sbom.py':
    ensure => file,
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
    source => 'puppet:///modules/macos_sbom/generate_sbom.py',
  }

  # Ensure the directory for SBOM output exists
  file { '/var/sbom':
    ensure => directory,
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  # Run the SBOM script at the end of the Puppet run
  exec { 'generate_sbom':
    command     => '/usr/local/bin/python3 /usr/local/bin/generate_sbom.py',
    path        => '/usr/local/bin:/usr/bin:/bin',
    refreshonly => true,
    subscribe   => File['/usr/local/bin/generate_sbom.py'],
  }
}
