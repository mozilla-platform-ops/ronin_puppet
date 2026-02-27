# Installs a Taskcluster binary directly from a GitHub release asset
#
# Example:
# packages::macos_taskcluster_binary { 'start-worker':
#   version          => '90.0.5',
#   arch             => 'arm64',
#   file_destination => '/usr/local/bin/start-worker',
#   sha256           => 'fab0f581c7c5b8a6c0c38806f31e9fa9316ed71be28659320bfd17344a7ca39c',
# }

define packages::macos_taskcluster_binary (
  String $version,
  String $arch,
  String $file_destination,
  Optional[String] $sha256 = undef,
  String $repo             = 'taskcluster/taskcluster',
) {
  $base = "https://github.com/${repo}/releases/download/v${version}"
  $asset = "${title}-darwin-${arch}"
  $url = "${base}/${asset}"

  $tmpfile = "/tmp/${asset}"

  exec { "download-${asset}":
    command => "/usr/bin/curl -L -o ${tmpfile} ${url}",
    creates => $tmpfile,
    path    => ['/usr/bin', '/bin'],
  }

  if $sha256 {
    exec { "verify-sha-${asset}":
      command     => "/usr/bin/shasum -a 256 ${tmpfile} | /usr/bin/grep -q ${sha256}",
      refreshonly => true,
      subscribe   => Exec["download-${asset}"],
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
