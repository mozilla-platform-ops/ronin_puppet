# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs a Taskcluster Linux binary directly from a GitHub release asset.
define packages::linux_taskcluster_binary (
  Pattern[/^v\d+\.\d+\.\d+$/] $version,
  Pattern[/^[0-9a-f]{64}$/] $sha256,
  String $file_destination,
  Optional[String] $asset_name = undef,
  String $repo                 = 'taskcluster/taskcluster',
) {
  include shared
  require packages::setup

  $taskcluster_arch = $facts['os']['architecture'] ? {
    'amd64'   => 'amd64',
    'x86_64'  => 'amd64',
    'arm64'   => 'arm64',
    'aarch64' => 'arm64',
    default   => fail("Unsupported Taskcluster Linux architecture ${facts['os']['architecture']}"),
  }

  $_asset_name = $asset_name ? { undef => $title, default => $asset_name }
  $asset       = "${_asset_name}-linux-${taskcluster_arch}"
  $release_url = "https://github.com/${repo}/releases/download/${version}/${asset}"
  $cache_dir   = '/usr/local/lib/taskcluster-binaries'
  $cache_file  = "${cache_dir}/${asset}-${version}"

  ensure_resource('file', $cache_dir, {
    'ensure' => 'directory',
    'owner'  => 'root',
    'group'  => 'root',
    'mode'   => '0755',
  })

  archive { $cache_file:
    source        => $release_url,
    checksum      => $sha256,
    checksum_type => 'sha256',
    extract       => false,
    cleanup       => false,
    require       => File[$cache_dir],
  }

  file { $file_destination:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    source  => "file://${cache_file}",
    require => Archive[$cache_file],
  }
}
