class linux_packages::caddy {
  if $facts['os']['name'] != 'Ubuntu' {
    fail("Cannot install Caddy on ${facts['os']['name']}")
  }
  unless $facts['os']['architecture'] in ['amd64', 'x86_64'] {
    fail("Unsupported Caddy architecture ${facts['os']['architecture']}")
  }

  # The Cloudsmith source can break all APT updates when its quota is exhausted.
  file { ['/etc/apt/sources.list.d/caddy-stable.list', '/usr/share/keyrings/caddy-stable-archive-keyring.gpg']:
    ensure => absent,
  }
  File['/etc/apt/sources.list.d/caddy-stable.list'] -> Exec <| title == 'apt-update-xvfb' |>
  File['/etc/apt/sources.list.d/caddy-stable.list'] -> Exec <| title == 'apt_update' |>

  $cache_dir = '/root/caddy-packages'
  $package_file = "${cache_dir}/caddy_2.11.7_linux_amd64.deb"

  file { $cache_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
  }

  archive { $package_file:
    source        => 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/caddy_2.11.7_linux_amd64.deb',
    checksum      => 'a22b914ffd1958da42bc7ab13b7b62c6100634e0798ab594891d2d61d53ba749',
    checksum_type => 'sha256',
    extract       => false,
    cleanup       => false,
    require       => File[$cache_dir],
  }

  package { 'caddy':
    # For dpkg, latest means the version in this fixed, verified source file.
    ensure   => latest,
    provider => dpkg,
    source   => $package_file,
    require  => Archive[$package_file],
  }
}
