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
#
# Developer-ID-signed build instead of the ad-hoc release asset:
# packages::macos_taskcluster_binary { 'generic-worker-multiuser':
#   version          => '91.0.2',
#   arch             => 'arm64',
#   file_destination => '/usr/local/bin/generic-worker-multiuser',
#   signed           => true,
#   sha256           => '3e2e5410959c3652f89751be9863a07e050beb6a28beb7522a5122b871fb8487',
# }

define packages::macos_taskcluster_binary (
  String $version,
  String $arch,
  String $file_destination,
  Optional[String] $asset_name = undef,
  Optional[String] $sha256     = undef,
  String $repo                 = 'taskcluster/taskcluster',
  Boolean $signed              = false,
) {
  require packages::setup

  $_asset_name = $asset_name ? { undef => $title, default => $asset_name }
  $asset       = "${_asset_name}-darwin-${arch}"

  # The download path has no signature check of its own, so for signed builds
  # the pinned digest IS the verification that we got the Developer-ID binary
  # and not something else. Refuse to fetch a signed asset without one.
  if $signed and !$sha256 {
    fail("[${module_name}] ${title}: signed => true requires a sha256")
  }

  # Primary source: GitHub release asset.
  $gh_url = "https://github.com/${repo}/releases/download/v${version}/${asset}"

  # Fallback source: ronin-puppet S3 package bucket, using the same layout the
  # legacy packages::macos_package_from_s3 define used. The S3 object is named
  # after the installed binary (title), not the GitHub asset name.
  $s3_object = "${title}-${version}-${arch}"
  $s3_url    = "https://${packages::setup::default_s3_domain}/${packages::setup::default_bucket}/macos/public/common/${s3_object}"

  # Developer-ID-signed source, used only when $signed is set. Upstream does
  # not publish signed macOS builds as GitHub release assets yet
  # (taskcluster/taskcluster#7413), and Mozilla only signs a subset of the
  # assets, so the signed builds live under their own `signed/` prefix in the
  # ronin package bucket -- named after the GitHub asset so the object name,
  # the cache file and the release asset all line up.
  $signed_url = "https://${packages::setup::default_s3_domain}/${packages::setup::default_bucket}/macos/public/common/signed/${asset}-${version}"

  # Cache downloaded binaries under a persistent, version-named path -- NOT
  # /tmp, which these workers wipe on reboot. They reboot between every task
  # (dozens of times a day), so a /tmp cache means re-downloading every binary
  # from GitHub on every boot even when the installed binary is already correct.
  # With the version in the path, `creates` skips the download once a version is
  # cached and only fetches again on a version bump; the cache also lets the
  # file resource restore a deleted binary without a network fetch.
  #
  # Signed builds get their own cache slot. Without the suffix, pointing a role
  # at the signed source would be a silent no-op on every host that already has
  # the ad-hoc build of that version cached: `creates` would skip the download
  # and the install destination would keep being synced from the stale ad-hoc
  # cache file. The separate slot also makes rollback free -- reverting the role
  # change re-points the install at the still-cached ad-hoc binary with no
  # network fetch.
  $cache_dir  = '/usr/local/lib/taskcluster-binaries'
  $cache_name = $signed ? {
    true    => "${asset}-${version}-signed",
    default => "${asset}-${version}",
  }
  $cache_file = "${cache_dir}/${cache_name}"

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
  #
  # The signed source has no fallback on purpose. Falling back to the ad-hoc
  # GitHub asset would quietly install a binary whose cdhash the TCC and PPPC
  # ScreenCapture grants no longer match, and a whole pool silently losing
  # screen capture is far harder to notice than a failed puppet run.
  $fetch_command = $signed ? {
    true    => "curl -fL -o ${cache_file}.part ${signed_url}",
    default => "(curl -fL -o ${cache_file}.part ${gh_url} || curl -fL -o ${cache_file}.part ${s3_url})",
  }

  exec { "download-${cache_name}":
    command  => "${fetch_command} && mv -f ${cache_file}.part ${cache_file}",
    creates  => $cache_file,
    path     => ['/usr/bin', '/bin'],
    provider => 'shell',
    require  => File[$cache_dir],
  }

  if $sha256 {
    # Delete a mismatched cache file so the next run re-downloads instead of
    # failing forever against a poisoned cache, and order the check ahead of
    # the install so a binary that fails verification never reaches
    # $file_destination.
    exec { "verify-sha-${cache_name}":
      command  => "/usr/bin/shasum -a 256 ${cache_file} | /usr/bin/grep -q ${sha256} || { /bin/rm -f ${cache_file}; exit 1; }",
      unless   => "/usr/bin/shasum -a 256 ${cache_file} | /usr/bin/grep -q ${sha256}",
      path     => ['/usr/bin', '/bin'],
      provider => 'shell',
      require  => Exec["download-${cache_name}"],
      before   => File[$file_destination],
    }
  }

  file { $file_destination:
    ensure  => file,
    mode    => '0755',
    owner   => 'root',
    group   => 'wheel',
    source  => "file://${cache_file}",
    require => Exec["download-${cache_name}"],
  }
}
