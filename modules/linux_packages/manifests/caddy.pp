class linux_packages::caddy {
  include apt

  # The Cloudsmith repository signs its index with an expired key.
  file { '/etc/apt/sources.list.d/caddy-stable.list':
    ensure => absent,
    before => Class['apt::update'],
    notify => Exec['apt_update'],
  }

  $version = '2.11.4'
  $arch = $facts['os']['architecture'] ? {
    'amd64'   => 'amd64',
    'x86_64'  => 'amd64',
    'arm64'   => 'arm64',
    'aarch64' => 'arm64',
    default   => fail("Unsupported Caddy architecture ${facts['os']['architecture']}"),
  }
  $checksum = $arch ? {
    'amd64' => '1c6f5404f3622e46d401d81f4af59677d46b886229c6694d60fd936b87c72d3bb5d1fcf42b55c8d555769fa75acf434ab618fc7e0df2c79cf8512ee580d38d06',
    'arm64' => 'c43c62b7b583b31c682b3c3e1a31cf03759fbab01dcb0fc7d7fc3a5ce1bef43403583e26133920634a730a9fe31dae1386af4d3f9f3fc19fcc2c29ebf19de235',
  }
  $filename = "caddy_${version}_linux_${arch}.deb"
  $package_path = "/var/cache/${filename}"

  archive { $package_path:
    source        => "https://github.com/caddyserver/caddy/releases/download/v${version}/${filename}",
    checksum      => $checksum,
    checksum_type => 'sha512',
    extract       => false,
    cleanup       => false,
  }

  package { 'caddy':
    ensure   => $version,
    provider => dpkg,
    source   => $package_path,
    require  => [Archive[$package_path], Exec['apt_update']],
  }
}
