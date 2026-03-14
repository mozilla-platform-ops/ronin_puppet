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
  $base = "https://github.com/${repo}/releases/download/v${version}"
  $_asset_name = $asset_name ? { undef => $title, default => $asset_name }
  $asset = "${_asset_name}-darwin-${arch}"
  $url = "${base}/${asset}"

  $tmpfile = "/tmp/${asset}-${version}"

  exec { "download-${asset}":
    command => "/usr/bin/curl -L -o ${tmpfile} ${url}",
    creates => $tmpfile,
    path    => ['/usr/bin', '/bin'],
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
