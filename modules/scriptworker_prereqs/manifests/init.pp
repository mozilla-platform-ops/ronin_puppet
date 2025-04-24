class scriptworker_prereqs {
  class { 'packages::python3':
    version => '3.8.3',
  }

  # Determine macOS version correctly for older and newer versions
  $mac_version = $facts['os']['release']['major']

  if $mac_version == '21' or $mac_version == '23' { # macOS 14+
    file { '/usr/local/tools/python3':
      ensure  => 'link',
      target  => '/usr/local/bin/python3',
      require => Class['packages::python3'],
    }
  } elsif $mac_version == '18' or $mac_version == '19' { # macOS 10.14 and 10.15
    # Ensure /tools directory exists only on older macOS versions
    file { '/tools':
      ensure => 'directory',
      owner  => 'root',
      group  => 'wheel',
      mode   => '0755',
    }

    file { '/tools/python3':
      ensure  => 'link',
      target  => '/usr/local/bin/python3',
      require => [Class['packages::python3'], File['/tools']],
    }

    # Ensure /builds directory exists only on older macOS versions
    file { '/builds':
      ensure => 'directory',
      owner  => 'root',
      group  => 'wheel',
      mode   => '0755',
    }
  } else {
    fail("Unsupported macOS version: ${mac_version}")
  }

  include dirs::builds

  # DeveloperIDCA.cer is only required on dep, but is harmless on prod
  file {
    '/tmp/DeveloperIDCA.cer':
      source => 'puppet:///modules/scriptworker_prereqs/DeveloperIDCA.cer',
  }
  exec {
    'install-developer-id-root':
      command => '/usr/bin/security unlock-keychain -u /Library/Keychains/System.keychain && /usr/bin/security add-trusted-cert -r trustAsRoot -k /Library/Keychains/System.keychain /tmp/DeveloperIDCA.cer',
      require => File['/tmp/DeveloperIDCA.cer'],
      unless  => "/usr/bin/security unlock-keychain -u /Library/Keychains/System.keychain && /usr/bin/security dump-keychain /Library/Keychains/System.keychain | /usr/bin/grep 'Developer ID Certification'",
      returns => [1],
  }

  # Accept the xcode license
  exec {
    'xcode_license_agree':
      command => '/usr/bin/xcodebuild -license accept',
  }
}
