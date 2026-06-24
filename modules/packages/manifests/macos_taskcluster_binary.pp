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

  $tmpfile = "/tmp/${asset}-${version}"

  # -f makes curl exit non-zero on HTTP errors so the S3 fallback fires, rather
  # than silently saving an error page as the binary.
  exec { "download-${asset}":
    command  => "curl -fL -o ${tmpfile} ${gh_url} || curl -fL -o ${tmpfile} ${s3_url}",
    creates  => $tmpfile,
    path     => ['/usr/bin', '/bin'],
    provider => 'shell',
  }

  if $sha256 {
    exec { "verify-sha-${asset}":
      command => "/usr/bin/shasum -a 256 ${tmpfile} | /usr/bin/grep -q ${sha256}",
      unless  => "/usr/bin/shasum -a 256 ${tmpfile} | /usr/bin/grep -q ${sha256}",
      require => Exec["download-${asset}"],
    }
  }

  file { $file_destination:
    ensure  => file,
    mode    => '0755',
    owner   => 'root',
    group   => 'wheel',
    source  => "file://${tmpfile}",
    require => Exec["download-${asset}"],
  }
}
