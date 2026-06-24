# Installs a Taskcluster binary directly from a GitHub release asset
#
# Examples:
# packages::macos_taskcluster_binary { 'start-worker':
#   version          => '97.0.1',
#   arch             => 'arm64',
#   file_destination => '/usr/local/bin/start-worker',
# }
#
# packages::macos_taskcluster_binary { 'generic-worker-simple':
#   version          => '97.0.1',
#   arch             => 'arm64',
#   file_destination => '/usr/local/bin/generic-worker-simple',
#   asset_name       => 'generic-worker-insecure',
# }

define packages::macos_taskcluster_binary (
  String $version,
  String $arch,
  String $file_destination,
  Optional[String] $asset_name = undef,
  Optional[String] $sha256     = undef,
  String $repo                 = 'taskcluster/taskcluster',
) {
  require packages::setup

  $_asset_name = $asset_name ? { undef => $title, default => $asset_name }
  $asset       = "${_asset_name}-darwin-${arch}"

  # Primary source: GitHub release asset.
  $gh_url = "https://github.com/${repo}/releases/download/v${version}/${asset}"

  # Fallback source: ronin-puppet S3 package bucket, using the same layout the
  # legacy packages::macos_package_from_s3 define used. The S3 object is named
  # after the installed binary (title), not the GitHub asset name.
  $s3_object = "${title}-${version}-${arch}"
  $s3_url    = "https://${packages::setup::default_s3_domain}/${packages::setup::default_bucket}/macos/public/common/${s3_object}"

  # Cache downloaded binaries under a persistent, version-named path -- NOT
  # /tmp, which these workers wipe on reboot. They reboot between every task
  # (dozens of times a day), so a /tmp cache means re-downloading every binary
  # from GitHub on every boot even when the installed binary is already correct.
  # With the version in the path, `creates` skips the download once a version is
  # cached and only fetches again on a version bump; the cache also lets the
  # file resource restore a deleted binary without a network fetch.
  $cache_dir  = '/usr/local/lib/taskcluster-binaries'
  $cache_file = "${cache_dir}/${asset}-${version}"

  ensure_resource('file', $cache_dir, {
    'ensure' => 'directory',
    'owner'  => 'root',
    'group'  => 'wheel',
    'mode'   => '0755',
  })

  # -f makes curl exit non-zero on HTTP errors so the S3 fallback fires, rather
  # than silently saving an error page as the binary. Download to a .part file
  # and only move it into place on success, so an interrupted/failed download
  # never leaves a truncated binary in the persistent cache (which `creates`
  # would otherwise treat as complete).
  exec { "download-${asset}":
    command  => "(curl -fL -o ${cache_file}.part ${gh_url} || curl -fL -o ${cache_file}.part ${s3_url}) && mv -f ${cache_file}.part ${cache_file}",
    creates  => $cache_file,
    path     => ['/usr/bin', '/bin'],
    provider => 'shell',
    require  => File[$cache_dir],
  }

  if $sha256 {
    exec { "verify-sha-${asset}":
      command => "/usr/bin/shasum -a 256 ${cache_file} | /usr/bin/grep -q ${sha256}",
      unless  => "/usr/bin/shasum -a 256 ${cache_file} | /usr/bin/grep -q ${sha256}",
      require => Exec["download-${asset}"],
    }
  }

  file { $file_destination:
    ensure  => file,
    mode    => '0755',
    owner   => 'root',
    group   => 'wheel',
    source  => "file://${cache_file}",
    require => Exec["download-${asset}"],
  }
}
