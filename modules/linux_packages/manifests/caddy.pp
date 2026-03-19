class linux_packages::caddy {
  include apt

  # Ensure necessary packages are installed
  package { ['debian-keyring', 'debian-archive-keyring', 'apt-transport-https', 'curl']:
    ensure => installed,
  }

  # Download and install Caddy GPG key
  exec { 'install_caddy_gpg_key':
    command => 'curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg',
    path    => '/usr/bin:/bin:/usr/sbin:/sbin',
    creates => '/usr/share/keyrings/caddy-stable-archive-keyring.gpg',
    require => Package['curl'],
  }

  # Add Caddy repository to sources list
  exec { 'add_caddy_repository':
    command => 'curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt | tee /etc/apt/sources.list.d/caddy-stable.list',
    path    => '/usr/bin:/bin:/usr/sbin:/sbin',
    creates => '/etc/apt/sources.list.d/caddy-stable.list',
    require => Exec['install_caddy_gpg_key'],
    notify  => Exec['apt_update'],
  }

  # Install Caddy
  package { 'caddy':
    ensure  => installed,
    require => Exec['apt_update'],
  }
}
