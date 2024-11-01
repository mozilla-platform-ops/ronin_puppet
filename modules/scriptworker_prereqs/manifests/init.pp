class scriptworker_prereqs {
  class { 'packages::python3':
    version => '3.8.3',
  }

  if $facts['os']['macosx']['version']['major'] == '14' {
    file { '/usr/local/tools/python3':
      ensure  => 'link',
      target  => '/usr/local/bin/python3',  # Correct target path
      require => Class['packages::python3'], # Ensure Python3 is installed before creating the symlink
    }
  } else {
    file { '/tools/python3':
      ensure  => 'link',
      target  => '/usr/local/bin/python3',
      require => Class['packages::python3'],
    }
  }

  include dirs::builds

  # DeveloperIDCA.cer is only required on dep, but is harmless on prod
  file {
    '/tmp/DeveloperIDCA.cer':
      source => 'puppet:///modules/scriptworker_prereqs/DeveloperIDCA.cer',
  }
  exec {
    'install-developer-id-root':
      command => '/usr/bin/security add-trusted-cert -r trustAsRoot -k /Library/Keychains/System.keychain /tmp/DeveloperIDCA.cer',
      require => File['/tmp/DeveloperIDCA.cer'],
      unless  => "/usr/bin/security dump-keychain /Library/Keychains/System.keychain | /usr/bin/grep 'Developer ID Certification'",
      returns => [1],
  }

  # Accept the xcode license
  exec {
    'xcode_license_agree':
      command => '/usr/bin/xcodebuild -license accept',
  }
}
