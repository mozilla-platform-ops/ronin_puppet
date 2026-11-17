# Root-controlled inputs for local Debian package installation.
class packages::deb_staging {
  file { '/var/cache/ronin-package-staging':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
  }

  file { '/var/cache/ronin-package-staging/debs-installed':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    source  => 'puppet:///modules/packages/debs-installed.sh',
    require => File['/var/cache/ronin-package-staging'],
  }
}
