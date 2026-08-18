class scriptworker_prereqs {

  # Determine macOS version
  $mac_version = $facts['os']['release']['major']

  # Everything below is aarch64-only: both the uv release asset and the
  # uv-managed python build are pinned to that architecture. Facter spells it
  # arm64 on Darwin.
  $arch = $facts['os']['architecture']
  unless $arch in ['aarch64', 'arm64'] {
    fail("Unsupported CPU architecture: ${arch} - scriptworker_prereqs requires aarch64")
  }

  case $mac_version {
    # macOS 14+ (aarch64). uv owns both the venv tooling and the interpreter.
    '21', '23', '24': {
      $uv_version = '0.12.4'
      $uv_checksum = '99a913b606194867b43086404412c1afe079547fee72ecfb6af7e7b0dd54b0c6'

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

      # Scoped to uv-* so it leaves the uv-managed pythons (/opt/tools/python) alone.
      exec { 'cleanup other UV installs':
        command     => "find /opt/tools/ -mindepth 1 -maxdepth 1 -type d -name 'uv-*' ! -name \"uv-${uv_version}\" -exec rm -rf {} +",
        onlyif      => 'ls /opt/tools/uv-*',
        path        => ['/usr/bin', '/bin'],
        subscribe   => Archive['install UV'],
        refreshonly => true,
      }

      # The interpreter the scriptworker venvs are built from. `uv venv` picks it
      # up through the python3 link this drops in /usr/local/bin.
      class { 'packages::uvpython':
        version => '3.14.6',
        require => File['/usr/local/bin/uv'],
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
        require => [Class['packages::uvpython'], File['/usr/local/tools']],
      }
    }
    # Older versions of macos are not supported.
    default: {
      fail("Unsupported macOS version: ${mac_version}")
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
