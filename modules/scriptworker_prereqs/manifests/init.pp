class scriptworker_prereqs {

  # Determine macOS version
  $mac_version = $facts['os']['release']['major']

  # Select Python version based on OS
  $python_version = $mac_version ? {
    '18'    => '3.8.3',
    '19'    => '3.8.3',
    '21'    => '3.11.0',
    '23'    => '3.11.0',
    default => fail("Unsupported macOS version: ${mac_version}"),
  }

  # Install appropriate Python version
  class { 'packages::python3':
    version => $python_version,
  }

  # Install virtualenv and setup tools symlink for macOS 14+ (mac_version 21 or 23)
  if $mac_version in ['21', '23'] {
    exec { 'install python3 virtualenv':
      command => '/Library/Frameworks/Python.framework/Versions/3.11/bin/python3 -m pip install virtualenv',
      unless  => '/Library/Frameworks/Python.framework/Versions/3.11/bin/python3 -m virtualenv --version',
      path    => ['/Library/Frameworks/Python.framework/Versions/3.11/bin', '/usr/bin', '/bin'],
      user    => 'root',
      require => Class['packages::python3'],
    }

    file { '/usr/local/tools':
      ensure => 'directory',
      owner  => 'root',
      group  => 'wheel',
      mode   => '0755',
    }

    file { '/usr/local/tools/python3':
      ensure  => 'link',
      target  => '/usr/local/bin/python3',
      require => [Class['packages::python3'], File['/usr/local/tools']],
    }

    $uv_version = '0.8.2'
    $uv_checksum = '954d24634d5f37fa26c7af75eb79893d11623fc81b4de4b82d60d1ade4bfca22'
    # Note: This is hard-coded to aarch64 architecture - we currently don't have plans on supporting old signers

    file { "/opt/tools/uv-${uv_version}":
      ensure => 'directory',
      owner  => 'root',
      group  => 'wheel',
      mode   => '0755',
    }

    archive { 'install UV':
      path            => '/tmp/uv.tar.gz',
      source          => "https://github.com/astral-sh/uv/releases/download/${uv_version}/uv-aarch64-apple-darwin.tar.gz",
      checksum        => $uv_checksum,
      checksum_type   => 'sha256',
      extract_command => 'tar xfz %s --strip-components=1',
      extract         => true,
      extract_path    => "/opt/tools/uv-${uv_version}",
      creates         => "/opt/tools/uv-${uv_version}/uv",
      require         => File["/opt/tools/uv-${uv_version}"],
    }

    file { '/usr/local/bin/uv':
      ensure  => 'link',
      target  => "/opt/tools/uv-${uv_version}/uv",
      require => Archive['install UV'],
    }

    exec { 'cleanup other UV installs':
      command     => "find /opt/tools/ -mindepth 1 -maxdepth 1 -type d ! -name \"uv-${uv_version}\" -exec rm -rf {} +",
      onlyif      => 'ls /opt/tools/uv-*',
      path        => ['/usr/bin', '/bin'],
      subscribe   => Archive['install UV'],
      refreshonly => true,
    }
  }

  # Legacy dirs and symlink for older macOS (macOS 10.14 and 10.15)
  if $mac_version in ['18', '19'] {
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

    file { '/builds':
      ensure => 'directory',
      owner  => 'root',
      group  => 'wheel',
      mode   => '0755',
    }
  }

  include dirs::builds

  file { '/tmp/DeveloperIDCA.cer':
    source => 'puppet:///modules/scriptworker_prereqs/DeveloperIDCA.cer',
  }

  exec { 'install-developer-id-root':
    command => '/usr/bin/security add-trusted-cert -r trustAsRoot -k /Library/Keychains/System.keychain /tmp/DeveloperIDCA.cer',
    require => File['/tmp/DeveloperIDCA.cer'],
    unless  => "/usr/bin/security dump-keychain /Library/Keychains/System.keychain | /usr/bin/grep 'Developer ID Certification'",
    returns => [1],
  }

  exec { 'xcode_license_agree':
    command => '/usr/bin/xcodebuild -license accept',
  }
}
